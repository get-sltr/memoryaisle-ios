import SwiftUI

struct UpgradePrompt: View {
    let feature: String
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.violet.opacity(0.5))

            Text("Pro feature")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(feature)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.violetDeep)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.violet.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.violet.opacity(0.1), lineWidth: 0.5)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
