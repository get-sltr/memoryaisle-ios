import SwiftUI

struct MiraChatView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat area
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer(minLength: Theme.Spacing.xl)

                    // Mira greeting
                    VStack(spacing: Theme.Spacing.md) {
                        MiraWaveform(state: .speaking, size: .hero)
                            .padding(.bottom, Theme.Spacing.sm)

                        Text("How can I help today?")
                            .font(Typography.displaySmall)
                            .foregroundStyle(Theme.Text.primary)
                            .multilineTextAlignment(.center)

                        Text("Ask me about meals, protein, groceries, or how your day is going.")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Quick actions
                    VStack(spacing: Theme.Spacing.sm) {
                        quickAction("What should I eat right now?", icon: "fork.knife")
                        quickAction("I'm feeling nauseous", icon: "leaf.fill")
                        quickAction("Generate my grocery list", icon: "cart.fill")
                        quickAction("How's my protein today?", icon: "chart.bar.fill")
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)

                    Spacer(minLength: 80)
                }
            }

            // Input bar
            inputBar
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Quick Action

    private func quickAction(_ text: String, icon: String) -> some View {
        InteractiveGlassCard(action: {
            inputText = text
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Accent.primary(for: scheme))
                    .frame(width: 24)

                Text(text)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Text.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Mic button
            Button {
                HapticManager.light()
            } label: {
                Image(systemName: "mic.fill")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Theme.Accent.primary(for: scheme))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Voice input")

            // Text field
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

            // Send button
            Button {
                HapticManager.medium()
                inputText = ""
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
}
