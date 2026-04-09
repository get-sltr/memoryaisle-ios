import SwiftUI

struct MiraFloatingButton: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.9))
                                .frame(width: 2.5, height: 7)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.9))
                                .frame(width: 2.5, height: 12)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.9))
                                .frame(width: 2.5, height: 16)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.9))
                                .frame(width: 2.5, height: 10)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.9))
                                .frame(width: 2.5, height: 8)
                        }
                    }
                    .shadow(
                        color: Color(hex: 0xA78BFA).opacity(0.3),
                        radius: 12, y: 4
                    )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40)
            }
        }
    }
}
