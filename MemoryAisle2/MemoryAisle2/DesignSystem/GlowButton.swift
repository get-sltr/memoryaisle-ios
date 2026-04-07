import SwiftUI

struct GlowButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(GlowPressStyle())
    }
}

private struct GlowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(pressed ? 0.9 : 0.6))
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.violet.opacity(pressed ? 0.3 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color.violet.opacity(pressed ? 0.6 : 0.3),
                        lineWidth: pressed ? 1 : 0.5
                    )
            )
            .shadow(
                color: Color.violet.opacity(pressed ? 0.5 : 0.25),
                radius: pressed ? 30 : 20,
                y: 4
            )
            .shadow(
                color: Color.violet.opacity(pressed ? 0.2 : 0.1),
                radius: 40,
                y: 8
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .brightness(pressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}
