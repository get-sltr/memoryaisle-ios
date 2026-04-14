import SwiftUI

/// Per-filter empty state messaging for the Reflection moments timeline.
/// Five filters, five copy variants. Centered column with MiraWaveform
/// at top, soft serif headline, and warm body text. No CTAs — empty
/// states are ambient invitations, not directives.
struct ReflectionEmptyState: View {
    let filter: ReflectionFilter

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 14) {
            MiraWaveform(state: .idle, size: .compact)
                .frame(height: 28)
                .padding(.bottom, 4)

            Text(headline)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)

            Text(bodyText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var headline: String {
        switch filter {
        case .all:      return "Your moments will live here."
        case .photos:   return "Photo moments appear here."
        case .meals:    return "Meal moments appear here."
        case .gym:      return "Gym moments appear here."
        case .feelings: return "Your own words live here."
        }
    }

    private var bodyText: String {
        switch filter {
        case .all:
            return "As you check in and show up for yourself, this space fills in on its own."
        case .photos:
            return "Every check-in photo becomes part of your story."
        case .meals:
            return "Recipes you save and meals you cook become part of your story."
        case .gym:
            return "Every session you log shows up here. From first squat to first mile."
        case .feelings:
            return "Words you share with Mira become part of your journey. Wins, hard days, real thoughts, all of it."
        }
    }
}
