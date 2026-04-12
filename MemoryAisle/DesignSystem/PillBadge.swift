import SwiftUI

enum PillStatus: String {
    case onTrack = "On Track"
    case behind = "Behind"
    case warning = "Warning"
    case nauseaSafe = "Nausea-Safe"
    case nauseaRisk = "Nausea Risk"
    case skip = "Skip"
    case neutral = "Neutral"

    var icon: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .behind: "exclamationmark.triangle.fill"
        case .warning: "xmark.circle.fill"
        case .nauseaSafe: "leaf.fill"
        case .nauseaRisk: "exclamationmark.triangle.fill"
        case .skip: "hand.raised.fill"
        case .neutral: "circle.fill"
        }
    }
}

struct PillBadge: View {
    @Environment(\.colorScheme) private var scheme

    let status: PillStatus
    let label: String?

    init(_ status: PillStatus, label: String? = nil) {
        self.status = status
        self.label = label
    }

    private var foregroundColor: Color {
        switch status {
        case .onTrack, .nauseaSafe:
            Theme.Semantic.onTrack(for: scheme)
        case .behind, .nauseaRisk:
            Theme.Semantic.behind(for: scheme)
        case .warning, .skip:
            Theme.Semantic.warning(for: scheme)
        case .neutral:
            Theme.Text.secondary(for: scheme)
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .onTrack, .nauseaSafe:
            Theme.Semantic.onTrackBg(for: scheme)
        case .behind, .nauseaRisk:
            Theme.Semantic.behindBg(for: scheme)
        case .warning, .skip:
            Theme.Semantic.warningBg(for: scheme)
        case .neutral:
            Theme.Text.secondary(for: scheme).opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch status {
        case .onTrack, .nauseaSafe:
            Theme.Semantic.onTrackBorder(for: scheme)
        case .behind, .nauseaRisk:
            Theme.Semantic.behindBorder(for: scheme)
        case .warning, .skip:
            Theme.Semantic.warningBorder(for: scheme)
        case .neutral:
            Theme.Text.secondary(for: scheme).opacity(0.12)
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 10))

            Text(label ?? status.rawValue)
                .font(Typography.label)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: Theme.glassBorderWidth)
        )
    }
}
