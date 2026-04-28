import SwiftUI

/// Editorial 4-point sparkle ("✦"). Pairs with `MiraBars` in the Mira tab
/// hero. Distinct from the SF-Symbol `sparkle` glyph used by `MiraWaveform`
/// because the editorial spec calls for the ASCII four-point form rendered
/// in serif type with a soft glow.
struct MiraSparkle: View {
    let isActive: Bool
    let isSpeaking: Bool

    var body: some View {
        Text("✦")
            .font(.system(size: 18))
            .foregroundStyle(Theme.Editorial.onSurface)
            .shadow(color: .white.opacity(0.5), radius: 6)
            .scaleEffect(isSpeaking ? 1.15 : 1.0)
            .opacity(isActive ? 1.0 : 0.7)
            .animation(.easeInOut(duration: 0.4), value: isSpeaking)
            .animation(.easeInOut(duration: 0.4), value: isActive)
            .accessibilityHidden(true)
    }
}
