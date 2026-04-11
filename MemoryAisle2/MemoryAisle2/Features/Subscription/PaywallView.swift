import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager()
    @State private var isPurchasing = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Close
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Hero
                    VStack(spacing: 16) {
                        MiraWaveform(state: .speaking, size: .hero)
                            .frame(height: 60)

                        Text("Unlock the\nfull experience")
                            .font(Typography.serifLarge)
                            .foregroundStyle(Theme.Text.primary)
                            .multilineTextAlignment(.center)
                            .tracking(0.3)

                        Text("Everything Mira can do, unlocked.")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                    .padding(.top, 16)

                    // Features
                    VStack(spacing: 8) {
                        featureRow("Unlimited barcode scans", icon: "barcode.viewfinder")
                        featureRow("Full adaptive meal planning", icon: "fork.knife")
                        featureRow("Unlimited Mira conversations", icon: "sparkle")
                        featureRow("Grocery list generation", icon: "cart")
                        featureRow("Body composition tracking", icon: "figure.arms.open")
                        featureRow("Training-day adjustments", icon: "dumbbell")
                        featureRow("Symptom pattern analysis", icon: "chart.line.uptrend.xyaxis")
                        featureRow("Provider report PDF", icon: "doc.text")
                        featureRow("Lock screen widgets", icon: "rectangle.on.rectangle")
                        featureRow("All product modes", icon: "slider.horizontal.3")
                    }
                    .padding(.horizontal, 24)

                    // Price card
                    VStack(spacing: 12) {
                        if let product = subscriptionManager.products.first {
                            Text(product.displayPrice)
                                .font(Typography.monoLarge)
                                .foregroundStyle(Theme.Text.primary)

                            Text("per year")
                                .font(Typography.bodySmall)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))

                            Text("That's less than $1/week")
                                .font(Typography.bodySmall)
                                .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.6))
                        } else {
                            Text("$49.99")
                                .font(Typography.monoLarge)
                                .foregroundStyle(Theme.Text.primary)

                            Text("per year")
                                .font(Typography.bodySmall)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.Accent.primary(for: scheme).opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.Accent.primary(for: scheme).opacity(0.15), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)

                    // CTA
                    VStack(spacing: 14) {
                        GlowButton(isPurchasing ? "Processing..." : "Start Pro") {
                            guard !isPurchasing else { return }
                            Task { await handlePurchase() }
                        }
                        .accessibilityLabel(isPurchasing ? "Processing purchase" : "Start Pro subscription")
                        .padding(.horizontal, 32)

                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Text("Restore purchase")
                                .font(Typography.bodySmall)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        }
                        .accessibilityLabel("Restore previous purchase")
                    }

                    // Legal
                    VStack(spacing: 4) {
                        Text("Payment charged to your Apple ID. Subscription auto-renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            if let termsURL = URL(string: "https://memoryaisle.app/terms") {
                                Link("Terms", destination: termsURL)
                            }
                            if let privacyURL = URL(string: "https://memoryaisle.app/privacy") {
                                Link("Privacy", destination: privacyURL)
                            }
                        }
                        .font(Typography.label)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                    Spacer(minLength: 40)
                }
            }
        }
        .themeBackground()
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.updateSubscriptionStatus()
        }
        .alert("Purchase failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text("Something went wrong. Please try again.")
        }
    }

    // MARK: - Feature Row

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Accent.primary(for: scheme))
                .frame(width: 20)

            Text(text)
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Spacer()

            Image(systemName: "checkmark")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
    }

    // MARK: - Purchase

    private func handlePurchase() async {
        isPurchasing = true
        do {
            let success = try await subscriptionManager.purchase()
            if success {
                HapticManager.success()
                dismiss()
            }
        } catch {
            showError = true
        }
        isPurchasing = false
    }
}
