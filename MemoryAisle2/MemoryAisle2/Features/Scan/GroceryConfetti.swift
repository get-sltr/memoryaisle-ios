import SwiftUI

struct ConfettiPiece: View {
    let index: Int
    @State private var animate = false

    private let colors: [UInt] = [
        0xA78BFA, 0x34D399, 0xFBBF24, 0x38BDF8,
        0xF87171, 0xFCA5A5, 0x67E8F9, 0xFDE68A
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: colors[index % colors.count]))
            .frame(
                width: CGFloat.random(in: 4...8),
                height: CGFloat.random(in: 8...16)
            )
            .rotationEffect(.degrees(animate ? Double.random(in: 0...360) : 0))
            .offset(
                x: animate ? CGFloat.random(in: -160...160) : 0,
                y: animate ? CGFloat.random(in: -80...200) : -50
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(
                    .easeOut(duration: Double.random(in: 1.2...2.5))
                    .delay(Double.random(in: 0...0.3))
                ) {
                    animate = true
                }
            }
    }
}

struct GroceryConfettiOverlay: View {
    @Environment(\.colorScheme) private var scheme
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<30, id: \.self) { i in
                        ConfettiPiece(index: i)
                    }
                }
                .frame(height: 200)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Semantic.onTrack(for: scheme))

                Text("Shopping done!")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(0.3)

                Text("Everything's checked off.\nTime to cook something amazing.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                GlowButton("Back to home") {
                    onDismiss()
                }
                .section(.grocery)
                .padding(.horizontal, 50)
                .padding(.top, 8)
            }
        }
        .transition(.opacity)
    }
}
