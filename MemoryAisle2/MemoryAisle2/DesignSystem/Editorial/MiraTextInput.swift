import SwiftUI

/// Toggle state for the Mira tab's input affordance. The voice surface owns
/// the conversation pipeline; this enum just decides which control set is
/// on screen — push-to-talk bars (`.voice`) or the typed input bar (`.text`).
enum MiraInputMode: Sendable, Equatable {
    case voice, text
}

/// Editorial text-input bar shown when the user taps the keyboard icon on
/// the voice hero. Sends typed messages through the same conversation
/// pipeline as voice; the caller is responsible for not triggering TTS so
/// the user can chat silently when they prefer typing.
struct MiraTextInput: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSend: (String) -> Void
    let onSwitchToVoice: () -> Void

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 16) {
            HairlineDivider().padding(.bottom, 4)
            switchToVoicePill
            inputRow
        }
    }

    private var switchToVoicePill: some View {
        Button(action: onSwitchToVoice) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                Text("VOICE")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.5)
            }
            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().stroke(Theme.Editorial.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch to voice")
    }

    private var inputRow: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("", text: $text, axis: .vertical)
                .placeholder(when: text.isEmpty) {
                    Text("Tell Mira what's on your mind...")
                        .font(Theme.Editorial.Typography.miraBody())
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                }
                .font(Theme.Editorial.Typography.miraBody())
                .foregroundStyle(Theme.Editorial.onSurface)
                .lineLimit(1...4)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit { onSend(text) }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

            Button {
                onSend(text)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(
                        trimmed.isEmpty
                            ? Theme.Editorial.onSurface.opacity(0.4)
                            : Theme.Editorial.onSurface
                    )
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .padding(.trailing, 8)
            .accessibilityLabel("Send message")
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.Editorial.hairline, lineWidth: 0.5)
        )
    }
}

private extension View {
    /// SwiftUI's `TextField(_:text:axis:)` init has no prompt parameter, so
    /// a ZStack overlay is the established pattern for a styled placeholder
    /// on a vertical-axis field.
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
