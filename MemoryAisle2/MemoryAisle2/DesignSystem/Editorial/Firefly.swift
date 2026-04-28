import CoreGraphics

struct Firefly: Identifiable, Sendable {
    let id: Int
    var anchor: CGPoint
    var offset: CGSize = .zero
    var velocity: CGSize = .zero
    let phase: Double
    let pulseSpeed: Double
    let size: CGFloat
    let driftSeedX: Double
    let driftSeedY: Double
}
