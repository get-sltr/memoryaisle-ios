import SwiftUI

// Loading shimmer effect for placeholder content.
// Uses a linear gradient highlight that sweeps across the target view.
struct ShimmerModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0.0),
                            .init(color: .white.opacity(scheme == .dark ? 0.12 : 0.18), location: 0.5),
                            .init(color: .white.opacity(0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    // Applies a loading shimmer highlight that sweeps left to right on a 1.4s loop.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview("Shimmer on section cards") {
    VStack(spacing: 16) {
        ForEach(SectionID.allCases, id: \.self) { id in
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Section.glass(id, for: .dark))
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Section.border(id, for: .dark), lineWidth: 0.5)
                )
                .shimmer()
        }
    }
    .padding()
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
