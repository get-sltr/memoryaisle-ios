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
                // Outer gradient ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: 0xA78BFA),
                                Color(hex: 0x7C3AED),
                                Color(hex: 0xC4B5FD),
                                Color(hex: 0x8B5CF6),
                                Color(hex: 0xA78BFA),
                            ],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 56, height: 56)

                // Inner solid violet circle
                Circle()
                    .fill(Color(hex: 0x7C3AED))
                    .frame(width: 46, height: 46)

                // Mira icon (waveform bars)
                HStack(spacing: 2) {
                    ForEach([8, 14, 18, 12, 9], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
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
