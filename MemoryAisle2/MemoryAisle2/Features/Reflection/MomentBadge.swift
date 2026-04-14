import SwiftUI

/// Small reusable pill badge for moment cards. Three variants:
/// milestone (green), tough day (amber), personal best (green with
/// different label). Sits in the top-right of a moment card to mark
/// special moments visually.
struct MomentBadge: View {
    enum Variant {
        case milestone
        case toughDay
        case personalBest
    }

    let variant: Variant

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(backgroundColor))
            .overlay(
                Capsule().stroke(borderColor, lineWidth: Theme.glassBorderWidth)
            )
            .accessibilityLabel(label)
    }

    private var label: String {
        switch variant {
        case .milestone: return "milestone"
        case .toughDay: return "tough day"
        case .personalBest: return "personal best"
        }
    }

    private var textColor: Color {
        switch variant {
        case .milestone, .personalBest:
            return Theme.Semantic.onTrack(for: scheme)
        case .toughDay:
            return Theme.Semantic.warning(for: scheme)
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .milestone, .personalBest:
            return Theme.Semantic.onTrack(for: scheme).opacity(0.06)
        case .toughDay:
            return Theme.Semantic.warning(for: scheme).opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .milestone, .personalBest:
            return Theme.Semantic.onTrack(for: scheme).opacity(0.12)
        case .toughDay:
            return Theme.Semantic.warning(for: scheme).opacity(0.15)
        }
    }
}
