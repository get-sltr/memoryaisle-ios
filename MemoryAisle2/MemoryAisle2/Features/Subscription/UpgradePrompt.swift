import SwiftUI

struct UpgradePrompt: View {
    @Environment(\.colorScheme) private var scheme
    let feature: String
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(Typography.titleSmall)
                .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.5))

            Text("Pro feature")
                .font(Typography.bodySmallBold)
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Text(feature)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade")
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.violetDeep)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Upgrade to Pro")
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Accent.primary(for: scheme).opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Accent.primary(for: scheme).opacity(0.1), lineWidth: 0.5)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
