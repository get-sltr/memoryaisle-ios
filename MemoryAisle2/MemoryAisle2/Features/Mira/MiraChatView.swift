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
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]

    @State private var inputText = ""
    @State private var messages: [MiraMessage] = []
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool

    private var profile: UserProfile? { profiles.first }
    private var todayLog: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if messages.isEmpty {
                            emptyState
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
                    .padding(.top, Theme.Spacing.md)
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
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            MiraWaveform(state: .speaking, size: .hero)
                .frame(height: 70)
                .padding(.bottom, 40)

            Text("How can I help?")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .tracking(0.3)

            Text("Meals, protein, groceries, or how your day is going.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 40)

            Spacer()
                .frame(height: 36)

            VStack(spacing: 8) {
                quickAction("What should I eat right now?", icon: "fork.knife")
                quickAction("I'm feeling nauseous", icon: "leaf.fill")
                quickAction("Generate my grocery list", icon: "cart.fill")
                quickAction("How's my protein today?", icon: "chart.bar.fill")
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
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
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
                Text("Mira is thinking...")
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

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                HapticManager.light()
            } label: {
                Image(systemName: "mic.fill")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Theme.Accent.primary(for: scheme))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Voice input")

            TextField("Ask Mira...", text: $inputText)
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

    private func sendMessage(_ text: String) {
        HapticManager.medium()
        let userMsg = MiraMessage(text, isUser: true)
        withAnimation(Theme.Motion.spring) {
            messages.append(userMsg)
            isTyping = true
        }

        let response = generateResponse(to: text)
        let delay = Double.random(in: 0.8...1.8)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(Theme.Motion.spring) {
                isTyping = false
                messages.append(MiraMessage(response))
            }
            HapticManager.light()
        }
    }

    // MARK: - Response Engine (Canned)

    private func generateResponse(to input: String) -> String {
        let lower = input.lowercased()
        let proteinNow = Int(todayLog?.proteinGrams ?? 0)
        let target = profile?.proteinTargetGrams ?? 140
        let deficit = max(0, target - proteinNow)
        let med = profile?.medication?.rawValue ?? "your medication"

        if lower.contains("eat") || lower.contains("meal") || lower.contains("hungry") {
            if deficit > 40 {
                return "You're \(deficit)g behind on protein. I'd suggest grilled chicken with quinoa and roasted vegetables. That'll get you about 42g of protein in one sitting. Quick to prep, easy on the stomach."
            } else if deficit > 0 {
                return "You're close to your protein target! A Greek yogurt parfait with hemp seeds and berries would close the gap. Only takes 2 minutes, and the probiotics help with GI comfort."
            } else {
                return "You've hit your protein target! For your next meal, focus on vegetables and hydration. A light salad with avocado and a big glass of water would be perfect."
            }
        }

        if lower.contains("nausea") || lower.contains("nauseous") || lower.contains("sick") {
            return "I hear you. On nausea days, go small and bland. Try plain rice with a soft-boiled egg, or a banana with a tablespoon of almond butter. Sip ginger tea between bites. Avoid anything high-fat or spicy until the wave passes. This is normal with \(med), especially days 1-2 after your dose."
        }

        if lower.contains("grocery") || lower.contains("shopping") || lower.contains("store") {
            return "Based on your targets, here's a quick grocery run: chicken breast, Greek yogurt, eggs, rice, frozen vegetables, bananas, almond butter, hemp seeds, and ginger tea. That covers about 5 days of high-protein, nausea-friendly meals. Want me to build out the full weekly list?"
        }

        if lower.contains("protein") || lower.contains("how") {
            return "Today you're at \(proteinNow)g out of \(target)g protein. That's \(deficit > 0 ? "\(deficit)g to go" : "target hit!"). \(deficit > 20 ? "You'll want to prioritize protein-dense options for your remaining meals." : "You're doing great. Keep up the consistency.")"
        }

        if lower.contains("water") || lower.contains("hydra") {
            let waterNow = todayLog?.waterLiters ?? 0
            return "You're at \(String(format: "%.1f", waterNow))L of water today. GLP-1 medications suppress your thirst response, so you may not feel thirsty even when you need fluids. Try keeping a water bottle visible and sipping throughout the day. Aim for \(String(format: "%.1f", profile?.waterTargetLiters ?? 2.5))L."
        }

        if lower.contains("weight") || lower.contains("progress") {
            return "Weight fluctuates day to day, especially on GLP-1s. What matters is the trend over weeks, not individual weigh-ins. Focus on protein compliance and training consistency. The body composition changes will follow. Connect HealthKit for automatic trend tracking."
        }

        if lower.contains("workout") || lower.contains("train") || lower.contains("gym") || lower.contains("exercise") {
            return "On training days, aim for a protein-rich meal 1-2 hours before and within 30 minutes after. If appetite is low, a protein shake works great post-workout. Don't skip carbs before lifting. Your muscles need glycogen for performance, even on a calorie deficit."
        }

        return "I'm here to help with your nutrition, meals, groceries, hydration, and how your body responds to \(med). Ask me anything about what to eat, how you're tracking, or what to buy at the store."
    }
}
