import SwiftUI

/// Touch-reactive firefly particle layer for night mode.
/// One Canvas, 14 particles, 30fps. Honors Reduce Motion (static fallback)
/// and Low Power Mode (6 particles, no touch physics).
///
/// The layer captures touch via DragGesture for attraction, but `allowsHitTesting`
/// is false on the body so taps still pass through to the buttons stacked above
/// it in the parent ZStack.
struct FirefliesLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var darkZoneFraction: CGFloat = 0.60

    @Binding var touchPoint: CGPoint?
    @State private var fireflies: [Firefly] = []
    @State private var lastUpdate: Date = .now
    @State private var isLowPower: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    init(touchPoint: Binding<CGPoint?> = .constant(nil)) {
        self._touchPoint = touchPoint
    }

    var body: some View {
        Group {
            if reduceMotion {
                staticFallback
            } else {
                animatedCanvas
            }
        }
        .allowsHitTesting(false)
    }

    private var animatedCanvas: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    for firefly in fireflies {
                        drawFirefly(firefly, at: now, in: size, context: context)
                    }
                }
                .onChange(of: timeline.date) { _, newDate in
                    updatePhysics(at: newDate, in: geo.size)
                }
            }
            .onAppear {
                if fireflies.isEmpty {
                    fireflies = makeFireflies(in: geo.size)
                }
            }
            .onChange(of: geo.size) { _, newSize in
                fireflies = makeFireflies(in: newSize)
            }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                    isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
            }
        }
    }

    private var staticFallback: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let fallbackPoints = makeFireflies(in: size).prefix(8)
                for firefly in fallbackPoints {
                    let pos = CGPoint(
                        x: firefly.anchor.x * size.width,
                        y: firefly.anchor.y * size.height
                    )
                    drawGlow(at: pos, size: firefly.size, opacity: 0.5, context: context)
                }
            }
        }
    }

    private func drawFirefly(_ firefly: Firefly, at time: TimeInterval, in size: CGSize, context: GraphicsContext) {
        let position = CGPoint(
            x: firefly.anchor.x * size.width + firefly.offset.width,
            y: firefly.anchor.y * size.height + firefly.offset.height
        )
        let pulse = sin(time * firefly.pulseSpeed + firefly.phase)
        let normalizedPulse = (pulse + 1.0) / 2.0
        let opacity = 0.15 + normalizedPulse * 0.80
        drawGlow(at: position, size: firefly.size, opacity: opacity, context: context)
    }

    private func drawGlow(at position: CGPoint, size: CGFloat, opacity: Double, context: GraphicsContext) {
        let outerR = size * 5.0
        let outerRect = CGRect(x: position.x - outerR, y: position.y - outerR, width: outerR * 2, height: outerR * 2)
        let outerGrad = Gradient(stops: [
            .init(color: Color(red: 1.0, green: 0.86, blue: 0.51).opacity(opacity * 0.35), location: 0),
            .init(color: Color(red: 1.0, green: 0.86, blue: 0.51).opacity(0), location: 1)
        ])
        context.fill(
            Path(ellipseIn: outerRect),
            with: .radialGradient(outerGrad, center: position, startRadius: 0, endRadius: outerR)
        )

        let innerR = size * 2.5
        let innerRect = CGRect(x: position.x - innerR, y: position.y - innerR, width: innerR * 2, height: innerR * 2)
        let innerGrad = Gradient(stops: [
            .init(color: Color(red: 1.0, green: 0.97, blue: 0.86).opacity(opacity * 0.7), location: 0),
            .init(color: Color(red: 1.0, green: 0.97, blue: 0.86).opacity(0), location: 1)
        ])
        context.fill(
            Path(ellipseIn: innerRect),
            with: .radialGradient(innerGrad, center: position, startRadius: 0, endRadius: innerR)
        )

        let coreRect = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)
        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(Color(red: 1.0, green: 0.98, blue: 0.92).opacity(opacity))
        )
    }

    private func updatePhysics(at now: Date, in size: CGSize) {
        let elapsed: Double = now.timeIntervalSince(lastUpdate)
        let dt: Double = Swift.max(0.001, Swift.min(0.1, elapsed))
        lastUpdate = now
        let timeNow: Double = now.timeIntervalSinceReferenceDate
        let useTouch = !isLowPower

        for index in fireflies.indices {
            var firefly = fireflies[index]

            let driftX = sin(timeNow * 0.4 + firefly.driftSeedX) * 18.0
            let driftY = sin(timeNow * 0.3 + firefly.driftSeedY) * 25.0
            firefly.velocity.width += (driftX - firefly.offset.width) * 0.8 * dt
            firefly.velocity.height += (driftY - firefly.offset.height) * 0.8 * dt

            if useTouch, let touch = touchPoint {
                let pos = CGPoint(
                    x: firefly.anchor.x * size.width + firefly.offset.width,
                    y: firefly.anchor.y * size.height + firefly.offset.height
                )
                let dx = touch.x - pos.x
                let dy = touch.y - pos.y
                let distance = sqrt(dx * dx + dy * dy)
                let radius: CGFloat = 220
                if distance < radius && distance > 1 {
                    let normalized = 1.0 - (distance / radius)
                    let strength = normalized * normalized * 60.0
                    firefly.velocity.width += (dx / distance) * strength * dt
                    firefly.velocity.height += (dy / distance) * strength * dt
                }
            }

            firefly.velocity.width *= 0.92
            firefly.velocity.height *= 0.92

            firefly.offset.width += firefly.velocity.width * dt * 60.0
            firefly.offset.height += firefly.velocity.height * dt * 60.0

            let maxDrift: CGFloat = 80
            firefly.offset.width = max(-maxDrift, min(maxDrift, firefly.offset.width))
            firefly.offset.height = max(-maxDrift, min(maxDrift, firefly.offset.height))

            fireflies[index] = firefly
        }
    }

    private func makeFireflies(in size: CGSize) -> [Firefly] {
        let count = isLowPower ? 6 : 14

        let darkAnchors: [CGPoint] = [
            CGPoint(x: 0.14, y: 0.06), CGPoint(x: 0.70, y: 0.11),
            CGPoint(x: 0.38, y: 0.16), CGPoint(x: 0.86, y: 0.21),
            CGPoint(x: 0.08, y: 0.26), CGPoint(x: 0.54, y: 0.31),
            CGPoint(x: 0.22, y: 0.36), CGPoint(x: 0.78, y: 0.41),
            CGPoint(x: 0.42, y: 0.46), CGPoint(x: 0.12, y: 0.51),
            CGPoint(x: 0.64, y: 0.56), CGPoint(x: 0.88, y: 0.58)
        ]
        let transitionAnchors: [CGPoint] = [
            CGPoint(x: 0.28, y: 0.65), CGPoint(x: 0.72, y: 0.70)
        ]
        let allAnchors = darkAnchors + transitionAnchors
        let limited = Array(allAnchors.prefix(count))

        return limited.enumerated().map { index, anchor in
            let isTransition = index >= darkAnchors.count
            return Firefly(
                id: index,
                anchor: anchor,
                phase: Double.random(in: 0...(2 * .pi)),
                pulseSpeed: Double.random(in: 0.6...1.1),
                size: isTransition ? 2.0 : 3.0,
                driftSeedX: Double(index) * 1.7 + 0.3,
                driftSeedY: Double(index) * 2.3 + 0.7
            )
        }
    }
}
