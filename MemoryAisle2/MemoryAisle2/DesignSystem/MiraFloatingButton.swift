import SwiftUI

struct MiraFloatingButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            ZStack {
                // Outer ring - gradient
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: 0xC084FC),
                                Color(hex: 0x818CF8),
                                Color(hex: 0x38BDF8),
                                Color(hex: 0x22D3EE),
                                Color(hex: 0x818CF8),
                                Color(hex: 0xC084FC),
                            ],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 58, height: 58)

                // Inner ring - solid violet
                Circle()
                    .stroke(Color(hex: 0xA78BFA), lineWidth: 2.5)
                    .frame(width: 44, height: 44)

                // Mira waveform bars in the center
                HStack(spacing: 2) {
                    ForEach([7, 12, 16, 10, 8], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.white.opacity(0.9))
                            .frame(width: 2.5, height: CGFloat(h))
                    }
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .shadow(
                color: Color(hex: 0xA78BFA).opacity(0.3),
                radius: 12, y: 4
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
    }
}
