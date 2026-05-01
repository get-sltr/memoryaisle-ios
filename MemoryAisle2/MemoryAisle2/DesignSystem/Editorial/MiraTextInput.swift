import SwiftUI

/// Editorial text-input bar for the Mira tab. Voice was pulled after
/// device testing showed the audio session was unreliable — this is now
/// the only input surface. `onSwitchToVoice` is kept on the API for the
/// dashboard's existing call site but is wired to a no-op in the parent.
struct MiraTextInput: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSend: (String) -> Void
    let onSwitchToVoice: () -> Void

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 12) {
            HairlineDivider().padding(.bottom, 4)
            inputRow
        }
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
