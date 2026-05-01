import OSLog
import SwiftData
import SwiftUI

/// Editorial Mira tab. Voice-first conversation surface:
///   masthead → chat history (mask-faded) → bars + sparkle hero → state hint
///
/// State machine (`MiraVoiceState`):
///   idle ↔ listening (push-to-talk on the bars)
///   listening → thinking (release sends transcript to MiraConversation)
///   thinking → speaking (Bedrock reply triggers TTS)
///   speaking → idle (TTS finishes, OR user taps to interrupt)
///   checkIn  → listening (Mira initiated; tap-to-respond — wired later)
struct MiraTabView: View {
    let mode: MAMode
    let onTapWordmark: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query private var pantry: [PantryItem]
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptoms: [SymptomLog]

    @State private var voice = VoiceManager.shared
    @State private var voiceState: MiraVoiceState = .idle

    /// PRIVACY INVARIANT: Mira conversations are ephemeral by product design
    /// (see LEGAL-MemoryAisle.md §2.5 and §2.7). Do NOT back this with
    /// SwiftData. Do NOT introduce a "past conversations" archive, server
    /// log, or any other form of persistence. The "we don't save it"
    /// guarantee is a product positioning Kevin holds to and a real user
    /// expectation set in the privacy policy.
    @State private var messages: [MiraTurn] = []
    @State private var conversation: MiraConversation?

    @State private var inputMode: MiraInputMode = .voice
    @State private var typedText: String = ""
    @FocusState private var typedFieldFocused: Bool

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
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            inputArea
                .padding(.bottom, 70)
        }
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
        .padding(.top, Theme.Editorial.Spacing.topInset)
        .onChange(of: voiceState) { _, newState in
            handleStateChange(newState)
        }
        .onChange(of: voice.isSpeaking) { _, speaking in
            // When VoiceManager's TTS finishes, slip back to idle automatically
            // unless the user has already moved us elsewhere.
            if !speaking, voiceState == .speaking {
                voiceState = .idle
            }
        }
        .onChange(of: voice.transcribedText) { _, text in
            // While listening, the live transcript can be displayed elsewhere
            // later; for now we just rely on it being present at release time.
            _ = text
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Stop any in-flight audio if the user backgrounds the app mid-turn.
            // Session deactivation is dispatched to a background task so the
            // mediaserverd IPC does not block main and trip the libdispatch
            // queue assertion during teardown.
            if newPhase != .active {
                voice.stopListening()
                voice.stopSpeaking()
                if voiceState != .idle {
                    voiceState = .idle
                }
                Task { await voice.deactivateAudioSessionAsync() }
            }
        }
        .task {
            _ = await voice.requestPermissions()
            ensureConversationReady()
        }
        .onDisappear {
            voice.stopListening()
            voice.stopSpeaking()
            Task { await voice.deactivateAudioSessionAsync() }
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
            return "\(salutation) Hold the bars when you want to talk. I'm here for meals, symptoms, your medication cycle, anything in your day."
        case .night:
            return "\(salutation) The day is winding down. Hold the bars when you want to talk."
        }
    }

    // MARK: - Input area (voice hero or text input)

    @ViewBuilder
    private var inputArea: some View {
        if inputMode == .voice {
            heroBlock
                .transition(.opacity)
        } else {
            MiraTextInput(
                text: $typedText,
                focused: $typedFieldFocused,
                onSend: { handleTextSend($0) },
                onSwitchToVoice: { switchToVoice() }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Hero block (voice mode)

    private var heroBlock: some View {
        VStack(spacing: 18) {
            HairlineDivider().padding(.bottom, 6)

            Text(voiceState.label)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3.2)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .accessibilityLabel(voiceState.label.lowercased())

            HStack(spacing: 16) {
                keyboardSwitchButton

                MiraBars(state: voiceState, amplitude: voice.audioLevel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .contentShape(Rectangle())
                    .gesture(pushToTalkGesture)
                    .onTapGesture {
                        if voiceState == .speaking {
                            voice.stopSpeaking()
                            voiceState = .idle
                        } else if voiceState == .checkIn {
                            voiceState = .listening
                        }
                    }
                    .accessibilityLabel(voiceState == .idle ? "Hold to talk to Mira" : "Mira voice surface")

                Color.clear
                    .frame(width: 44, height: 44)
                    .opacity(voiceState == .idle ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)

            MiraSparkle(isActive: voiceState != .idle, isSpeaking: voiceState == .speaking)

            if !voiceState.hint.isEmpty {
                Text(voiceState.hint)
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                    .accessibilityLabel(voiceState.hint.lowercased())
            } else {
                Color.clear.frame(height: 12)
            }
        }
    }

    /// Keyboard glyph balanced opposite a clear 44x44 spacer so the bars
    /// remain visually centered. Hidden during active voice states because
    /// the user is mid-turn and shouldn't be invited to swap modes.
    private var keyboardSwitchButton: some View {
        Button(action: switchToTextInput) {
            Image(systemName: "keyboard")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(voiceState == .idle ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: voiceState)
        .disabled(voiceState != .idle)
        .accessibilityLabel("Switch to typing")
    }

    // MARK: - Push-to-talk gesture

    private var pushToTalkGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.05)
            .onChanged { _ in
                if voiceState == .idle || voiceState == .checkIn {
                    HapticManager.light()
                    voiceState = .listening
                }
            }
            .onEnded { _ in
                if voiceState == .listening {
                    voiceState = .thinking
                }
            }
    }

    // MARK: - State transitions

    private func handleStateChange(_ newState: MiraVoiceState) {
        switch newState {
        case .listening:
            voice.transcribedText = ""
            voice.startListening()
        case .thinking:
            voice.stopListening()
            handleUserTurnEnd()
        case .speaking, .idle, .checkIn:
            break
        }
    }

    private func handleUserTurnEnd() {
        let raw = voice.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            // No transcript — bounce back to idle without burning a Mira call.
            voiceState = .idle
            return
        }

        let userTurn = MiraTurn(author: .user, timestamp: timestampNow(), body: raw)
        messages.append(userTurn)

        Task { @MainActor in
            await runMiraTurn(userText: raw)
        }
    }

    private func runMiraTurn(userText: String, speakReply: Bool = true) async {
        ensureConversationReady()
        guard let conversation, let profile else {
            if speakReply { voiceState = .idle }
            return
        }

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
            if speakReply {
                voiceState = .speaking
                voice.speak(trimmed)
            }
        } catch {
            logger.error("Mira turn failed: \(error.localizedDescription, privacy: .public)")
            messages.append(MiraTurn(
                author: .mira,
                timestamp: timestampNow(),
                body: "I'm having trouble reaching the network. Try once more in a moment."
            ))
            if speakReply { voiceState = .idle }
        }
    }

    // MARK: - Text input mode

    private func switchToTextInput() {
        HapticManager.light()
        withAnimation(.easeInOut(duration: 0.3)) {
            inputMode = .text
        }
        // Slight delay so the swap animation lands before the keyboard
        // springs in — async/await rather than asyncAfter per house rules.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            typedFieldFocused = true
        }
    }

    private func switchToVoice() {
        typedFieldFocused = false
        withAnimation(.easeInOut(duration: 0.3)) {
            inputMode = .voice
        }
    }

    private func handleTextSend(_ text: String) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        HapticManager.light()

        messages.append(MiraTurn(author: .user, timestamp: timestampNow(), body: raw))
        typedText = ""

        Task { @MainActor in
            await runMiraTurn(userText: raw, speakReply: false)
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
