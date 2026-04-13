import SwiftData
import SwiftUI

struct MiraMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(_ text: String, isUser: Bool = false) {
        self.text = text
        self.isUser = isUser
        self.timestamp = .now
    }
}

struct MiraChatView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]

    // Optional initial prompt seeded as Mira's first message when the view
    // is opened with a specific context (e.g. "Ready to generate your first
    // meal plan?" from the Day 1 dashboard).
    let initialPrompt: String?

    init(initialPrompt: String? = nil) {
        self.initialPrompt = initialPrompt
    }

    @State private var inputText = ""
    @State private var messages: [MiraMessage] = []
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool

    private var profile: UserProfile? { profiles.first }
    private var todayLog: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var isOnMedication: Bool {
        profile?.medication != nil
    }

    private var quickActions: [(text: String, icon: String)] {
        if isOnMedication {
            return [
                ("What should I eat right now?", "fork.knife"),
                ("I'm feeling nauseous", "leaf.fill"),
                ("Generate my grocery list", "cart.fill"),
                ("How's my protein today?", "chart.bar.fill")
            ]
        } else {
            return [
                ("What should I eat right now?", "fork.knife"),
                ("Best pre-workout meal?", "bolt.fill"),
                ("Generate my grocery list", "cart.fill"),
                ("How's my protein today?", "chart.bar.fill")
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if messages.isEmpty {
                            emptyState
                                .padding(.bottom, 60)
                        } else {
                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                            if isTyping {
                                typingIndicator
                            }
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            inputBar
        }
        .section(.mira)
        .themeBackground()
        .navigationBarHidden(true)
        .onAppear {
            seedInitialPromptIfNeeded()
        }
    }

    private func seedInitialPromptIfNeeded() {
        guard let prompt = initialPrompt, messages.isEmpty else { return }
        messages.append(MiraMessage(prompt, isUser: false))
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack {
            CloseButton(action: { dismiss() })
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State (no voice — waveform is pure decoration)

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            MiraWaveform(state: .idle, size: .hero)
                .frame(minHeight: 70)
                .padding(.bottom, 28)

            Text("How can I help?")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("Type your question below, or tap a suggestion")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 10)

            Spacer().frame(height: 36)

            VStack(spacing: 8) {
                ForEach(quickActions, id: \.text) { action in
                    quickAction(action.text, icon: action.icon)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Quick Action

    private func quickAction(_ text: String, icon: String) -> some View {
        Button {
            sendMessage(text)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.violet)
                    .frame(width: 20)

                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: MiraMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if !message.isUser {
                    HStack(spacing: 6) {
                        MiraWaveform(state: .idle, size: .hero)
                            .scaleEffect(0.35, anchor: .leading)
                            .frame(width: 30, height: 14)
                        Text("Mira")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.violet.opacity(0.6))
                    }
                }

                Text(message.text)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Text.primary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm + 2)
                    .background(
                        message.isUser
                            ? Color.violetDeep
                            : Theme.Surface.strong(for: scheme)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(
                        message.isUser
                            ? nil
                            : RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                    )
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                MiraWaveform(state: .thinking, size: .hero)
                    .scaleEffect(0.35, anchor: .leading)
                    .frame(width: 30, height: 14)
                Text("Mira is thinking…")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Surface.glass(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

            Spacer()
        }
    }

    // MARK: - Input Bar (text-only, no mic)

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask Mira…", text: $inputText)
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.primary)
                .focused($isInputFocused)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Surface.glass(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
                .onSubmit { sendCurrentInput() }

            Button {
                sendCurrentInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.isEmpty
                            ? Theme.Text.tertiary(for: scheme)
                            : Theme.Accent.primary(for: scheme)
                    )
            }
            .disabled(inputText.isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.ultraThinMaterial)
    }

    // MARK: - Send & Respond

    private func sendCurrentInput() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        sendMessage(inputText)
        inputText = ""
    }

    private let miraClient = MiraAPIClient()

    private func sendMessage(_ text: String) {
        HapticManager.medium()
        let userMsg = MiraMessage(text, isUser: true)
        withAnimation(Theme.Motion.spring) {
            messages.append(userMsg)
            isTyping = true
        }

        let context: MiraAPIClient.MiraContext
        if let p = profile {
            let anon = MedicationAnonymizer.anonymize(
                profile: p,
                cyclePhase: nil,
                symptomState: "unknown",
                proteinConsumed: Int(todayLog?.proteinGrams ?? 0),
                waterConsumed: todayLog?.waterLiters ?? 0,
                isTrainingDay: false
            )
            context = MiraAPIClient.MiraContext(
                medicationClass: anon.medicationClass,
                doseTier: anon.doseTier,
                daysSinceDose: anon.daysSinceDose,
                phase: anon.phase,
                symptomState: anon.symptomState,
                mode: anon.productMode,
                proteinTarget: anon.proteinTargetGrams,
                proteinToday: anon.proteinConsumedGrams,
                waterToday: anon.waterConsumedLiters,
                trainingLevel: anon.trainingLevel,
                trainingToday: anon.trainingToday,
                calorieTarget: anon.calorieTarget,
                dietaryRestrictions: anon.dietaryRestrictions
            )
        } else {
            context = MiraAPIClient.MiraContext(
                medicationClass: nil, doseTier: nil,
                daysSinceDose: nil, phase: nil,
                symptomState: nil, mode: nil,
                proteinTarget: nil, proteinToday: nil,
                waterToday: nil, trainingLevel: nil,
                trainingToday: nil, calorieTarget: nil,
                dietaryRestrictions: nil
            )
        }

        Task {
            do {
                let reply = try await miraClient.send(message: text, context: context)
                await MainActor.run {
                    withAnimation(Theme.Motion.spring) {
                        isTyping = false
                        messages.append(MiraMessage(reply))
                    }
                    HapticManager.light()
                }
            } catch {
                await MainActor.run {
                    withAnimation(Theme.Motion.spring) {
                        isTyping = false
                        messages.append(MiraMessage("I'm having trouble connecting right now. \(error.localizedDescription)"))
                    }
                }
            }
        }
    }
}
