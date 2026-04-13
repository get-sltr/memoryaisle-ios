import SwiftUI

struct ReflectionView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("REFLECTION")
                .font(Typography.label)
                .letterSpaced(1.5)
                .foregroundStyle(Theme.Accent.ghost(for: scheme))

            Text("Look how far you've come.")
                .font(Typography.serifLarge)
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.screenH)

            Text("Your moments will live here. As you check in and show up for yourself, this space fills in on its own.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.screenH + 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themeBackground()
    }
}
