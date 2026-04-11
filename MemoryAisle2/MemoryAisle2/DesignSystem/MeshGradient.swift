import SwiftUI

// Animated mesh gradient for hero headers and Mira's chat surface.
// Three radial gradients slowly drift between anchor positions on an 8s cycle.
// Battery-safe: uses TimelineView(.animation) which pauses when off-screen.
struct MeshGradientView: View {
    @Environment(\.colorScheme) private var scheme
    let section: SectionID
    var intensity: Double = 0.55

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: 8.0)) / 8.0
                let (a, b, c) = SectionPalette.meshTones(section, for: scheme)

                canvas.blendMode = .normal
                canvas.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.indigoBlack)
                )

                drawGradientBlob(
                    canvas: &canvas,
                    size: size,
                    color: a.opacity(intensity),
                    normCenter: blobCenter(phase, base: CGPoint(x: 0.15, y: 0.25), amp: 0.08),
                    normRadius: 0.75
                )
                drawGradientBlob(
                    canvas: &canvas,
                    size: size,
                    color: b.opacity(intensity * 0.85),
                    normCenter: blobCenter(phase + 0.33, base: CGPoint(x: 0.80, y: 0.35), amp: 0.10),
                    normRadius: 0.70
                )
                drawGradientBlob(
                    canvas: &canvas,
                    size: size,
                    color: c.opacity(intensity * 0.75),
                    normCenter: blobCenter(phase + 0.66, base: CGPoint(x: 0.55, y: 0.90), amp: 0.07),
                    normRadius: 0.80
                )
            }
        }
        .overlay(
            LinearGradient(
                colors: [.clear, Color.indigoBlack.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .drawingGroup()
    }

    private func blobCenter(_ phase: Double, base: CGPoint, amp: Double) -> CGPoint {
        let wrapped = phase.truncatingRemainder(dividingBy: 1.0)
        let angle = wrapped * 2 * .pi
        let dx = CGFloat(cos(angle) * amp)
        let dy = CGFloat(sin(angle) * amp)
        return CGPoint(x: base.x + dx, y: base.y + dy)
    }

    private func drawGradientBlob(
        canvas: inout GraphicsContext,
        size: CGSize,
        color: Color,
        normCenter: CGPoint,
        normRadius: Double
    ) {
        let center = CGPoint(x: normCenter.x * size.width, y: normCenter.y * size.height)
        let radius = CGFloat(normRadius) * max(size.width, size.height)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [color, color.opacity(0)]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
        canvas.fill(Path(ellipseIn: rect), with: shading)
    }
}

#Preview("Dark — each section") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(SectionID.allCases, id: \.self) { id in
                MeshGradientView(section: id)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        Text(id.rawValue.capitalized)
                            .foregroundStyle(.white)
                            .font(.headline),
                        alignment: .bottomLeading
                    )
                    .padding(.horizontal)
            }
        }
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}

#Preview("Light — each section") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(SectionID.allCases, id: \.self) { id in
                MeshGradientView(section: id)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal)
            }
        }
    }
    .background(Color.white)
    .preferredColorScheme(.light)
}
