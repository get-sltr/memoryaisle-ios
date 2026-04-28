import SwiftUI

/// Mira's signature waveform + sparkle followed by an italic one-liner.
/// Reuses `MiraWaveform.compact` so the avatar stays a single source of truth.
struct MiraLine: View {
    let message: String
    var state: MiraState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HairlineDivider()
            HStack(alignment: .center, spacing: 10) {
                MiraWaveform(state: state, size: .compact)
                Text(message)
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mira: \(message)")
    }
}
