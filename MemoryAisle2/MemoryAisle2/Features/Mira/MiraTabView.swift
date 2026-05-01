import OSLog
import SwiftData
import SwiftUI

/// Editorial Mira tab. Text-only conversation surface:
///   masthead → chat history (mask-faded) → text input
///
/// Voice (push-to-talk + TTS) was pulled after device testing showed the
/// audio session was unreliable across the speak/listen handoff. The
/// VoiceManager service still exists for any future feature that needs it,
/// but no surface in the editorial app currently drives it.
struct MiraTabView: View {
    let mode: MAMode
    let onTapWordmark: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query(sort: \PantryItem.addedDate, order: .reverse) private var pantry: [PantryItem]
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptoms: [SymptomLog]

    /// PRIVACY INVARIANT: Mira conversations are ephemeral by product design
    /// (see LEGAL-MemoryAisle.md §2.5 and §2.7). Do NOT back this with
    /// SwiftData. Do NOT introduce a "past conversations" archive, server
    /// log, or any other form of persistence. The "we don't save it"
    /// guarantee is a product positioning Kevin holds to and a real user
    /// expectation set in the privacy policy.
    @State private var messages: [MiraTurn] = []
    @State private var conversation: MiraConversation?

    @State private var typedText: String = ""
    @FocusState private var typedFieldFocused: Bool
    @State private var isSending: Bool = false

    private let logger = Logger(subsystem: "com.memoryaisle.MiraTab", category: "ChatLoop")

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Masthead(
                wordmark: "MIRA",
                trailing: mastheadTrailing,
                onTapWordmark: onTapWordmark
            )
            .padding(.bottom, 16)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if messages.isEmpty {
                            openingLine
                        } else {
                            ForEach(messages) { turn in
                                MiraChatBubble(
                                    author: turn.author == .mira ? .mira : .user,
                                    timestamp: turn.timestamp,
                                    text: turn.body
                                )
                                .id(turn.id)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Lets the user swipe the chat area down to dismiss the
                // keyboard, restoring access to the tab bar without a
                // dedicated close button. Standard iMessage / Messages
                // pattern.
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            MiraTextInput(
                text: $typedText,
                focused: $typedFieldFocused,
                onSend: { handleTextSend($0) },
                onSwitchToVoice: {}  // voice mode dropped; closure left as no-op
            )
            // 70pt clears the tab bar when the keyboard is down. When the
            // keyboard is up the system already lifts the input above the
            // keyboard, so the extra padding would push it back down.
            .padding(.bottom, typedFieldFocused ? 0 : 70)
        }
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
        .padding(.top, Theme.Editorial.Spacing.topInset)
        .task {
            ensureConversationReady()
            drainPendingPrompt()
        }
        .onChange(of: appState.pendingMiraPrompt) { _, newValue in
            // Tab is already mounted when the dashboard queues a prompt;
            // the .task above only fires on first appearance, so a live
            // observer covers subsequent arrivals.
            if newValue != nil {
                drainPendingPrompt()
            }
        }
    }

    // MARK: - Masthead trailing

    private var mastheadTrailing: String {
        switch mode {
        case .day:   RomanNumeral.dateString(from: Date())
        case .night: RomanNumeral.eveningString(from: Date())
        }
    }

    // MARK: - Empty-state opening line

    private var openingLine: some View {
        MiraChatBubble(
            author: .mira,
            timestamp: openingTimestamp,
            text: openingMessage
        )
    }

    private var openingTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH : mm"
        return formatter.string(from: Date())
    }

    private var openingMessage: String {
        let name = profile?.name ?? ""
        let salutation = name.isEmpty ? "Hello." : "Hello, \(name)."
        switch mode {
        case .day:
            return "\(salutation) Type a question and I'll help with meals, symptoms, your medication cycle, anything in your day."
        case .night:
            return "\(salutation) The day is winding down. What's on your mind?"
        }
    }

    // MARK: - Pending prompt drain

    /// Consume any prompt the dashboard's "Tell Me More" card queued in
    /// AppState. Lands as a normal user turn via `handleTextSend`.
    private func drainPendingPrompt() {
        guard let prompt = appState.pendingMiraPrompt,
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        appState.pendingMiraPrompt = nil
        handleTextSend(prompt)
    }

    // MARK: - Send

    private func handleTextSend(_ text: String) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isSending else { return }
        HapticManager.light()

        messages.append(MiraTurn(author: .user, timestamp: timestampNow(), body: raw))
        typedText = ""

        Task { @MainActor in
            isSending = true
            await runMiraTurn(userText: raw)
            isSending = false
        }
    }

    private func runMiraTurn(userText: String) async {
        ensureConversationReady()
        guard let conversation, let profile else { return }

        let context = MiraEngine.buildAnonymizedContext(
            profile: profile,
            nutritionLogs: logs,
            symptomLogs: symptoms,
            cyclePhase: cyclePhase(for: profile),
            isTrainingDay: false
        )

        do {
            let reply = try await conversation.send(
                userText: userText,
                context: context,
                recentMeals: recentMealNames(),
                pantryItems: pantry.prefix(20).map(\.name)
            )
            let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(MiraTurn(author: .mira, timestamp: timestampNow(), body: trimmed))
        } catch {
            logger.error("Mira turn failed: \(error.localizedDescription, privacy: .public)")
            messages.append(MiraTurn(
                author: .mira,
                timestamp: timestampNow(),
                body: "I'm having trouble reaching the network. Try once more in a moment."
            ))
        }
    }

    // MARK: - Helpers

    private func ensureConversationReady() {
        if conversation == nil {
            let executor = MiraToolExecutor(context: modelContext)
            conversation = MiraConversation(executor: executor)
        }
    }

    private func cyclePhase(for profile: UserProfile) -> CyclePhase? {
        guard let day = profile.injectionDay else { return nil }
        return InjectionCycleEngine.currentPhase(injectionDay: day)
    }

    private func recentMealNames() -> [String] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) else {
            return []
        }
        var seen = Set<String>()
        var ordered: [String] = []
        for log in logs where log.date >= cutoff {
            guard let raw = log.foodName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            let key = raw.lowercased()
            if seen.insert(key).inserted {
                ordered.append(raw)
                if ordered.count >= 10 { break }
            }
        }
        return ordered
    }

    private func timestampNow() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH : mm"
        return f.string(from: Date())
    }
}

// MARK: - Local conversation entry

/// Session-only chat turn. Persistence lives in the lower-level
/// `MiraConversation` history; the editorial UI only needs a render-friendly
/// list keyed by UUID for SwiftUI's diffing.
struct MiraTurn: Identifiable, Sendable {
    enum Author: Sendable { case mira, user }

    let id: UUID = UUID()
    let author: Author
    let timestamp: String
    let body: String
}
