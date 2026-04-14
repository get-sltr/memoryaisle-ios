import SwiftUI

/// The three-stat horizontal row at the top of Reflection: LBS / LEAN /
/// DAYS. Layout collapses gracefully when leanDelta is nil (no body fat
/// or lean mass data yet) — only LBS and DAYS render with one divider
/// instead of two.
struct TransformationStatsRow: View {
    let stats: TransformationStats

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            if let lbsDelta = stats.lbsDelta {
                statCell(
                    value: formatted(lbsDelta),
                    label: lbsLabel,
                    color: Theme.Text.primary
                )
                if shouldShowLean || stats.days != nil {
                    divider
                }
            }
            if let leanDelta = stats.leanDelta {
                statCell(
                    value: formatted(abs(leanDelta)),
                    label: "LEAN",
                    color: Theme.Semantic.onTrack(for: scheme)
                )
                if stats.days != nil {
                    divider
                }
            }
            if let days = stats.days {
                statCell(
                    value: "\(days)",
                    label: "DAYS",
                    color: Theme.Text.primary
                )
            }
        }
        .padding(.horizontal, 28)
    }

    private var shouldShowLean: Bool {
        stats.leanDelta != nil
    }

    private var lbsLabel: String {
        switch stats.direction {
        case .lost: return "LBS LOST"
        case .gained: return "LBS GAINED"
        case .none: return "LBS CHANGED"
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.Text.hint(for: scheme))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Border.glass(for: scheme))
            .frame(width: Theme.glassBorderWidth, height: 28)
    }

    private func formatted(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
