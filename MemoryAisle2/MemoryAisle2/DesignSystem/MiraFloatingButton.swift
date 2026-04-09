import SwiftUI

struct MiraFloatingButton: View {
    let action: () -> Void
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        GeometryReader { geo in
            buttonContent
                .position(
                    x: geo.size.width - 50 + offset.width,
                    y: geo.size.height - 160 + offset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { value in
                            lastOffset = offset
                            // Snap to nearest horizontal edge
                            let currentX = geo.size.width - 50 + offset.width
                            let snapX = currentX < geo.size.width / 2
                                ? 50 - (geo.size.width - 50)
                                : 0.0
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset.width = snapX + lastOffset.width - offset.width + offset.width
                                lastOffset.width = snapX
                                offset.width = snapX
                            }
                        }
                )
                .onTapGesture {
                    HapticManager.medium()
                    action()
                }
        }
        .allowsHitTesting(true)
    }

    private var buttonContent: some View {
        ZStack {
            // Outer gradient ring
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

            // Inner solid violet ring
            Circle()
                .stroke(Color(hex: 0xA78BFA), lineWidth: 2.5)
                .frame(width: 44, height: 44)

            // Mira waveform bars
            HStack(spacing: 2) {
                ForEach([7, 12, 16, 10, 8], id: \.self) { h in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.9))
                        .frame(width: 2.5, height: CGFloat(h))
                }
            }
        }
        .shadow(color: Color(hex: 0xA78BFA).opacity(0.3), radius: 12, y: 4)
    }
}
