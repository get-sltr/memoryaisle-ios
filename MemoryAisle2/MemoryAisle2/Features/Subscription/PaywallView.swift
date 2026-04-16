import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
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
                    VStack(spacing: 10) {
                        Text("MemoryAisle Pro")
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)

                        if let product = subscriptionManager.products.first {
                            Text(product.displayPrice)
                                .font(Typography.monoLarge)
                                .foregroundStyle(Theme.Text.primary)
                        } else {
                            Text("$49.99")
                                .font(Typography.monoLarge)
                                .foregroundStyle(Theme.Text.primary)
                        }

                        Text("per year \u{00b7} auto-renews annually")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))

                        Text("Less than $1/week")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.6))
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
                        GlowButton(ctaTitle) {
                            guard !isPurchasing else { return }
                            Task { await handlePurchase() }
                        }
                        .accessibilityLabel(ctaAccessibility)
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
                    VStack(spacing: 6) {
                        Text("MemoryAisle Pro is a $49.99/year auto-renewable subscription. Payment is charged to your Apple ID at confirmation. Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings \u{203a} Apple ID \u{203a} Subscriptions.")
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            if let termsURL = URL(string: "https://memoryaisle.app/terms") {
                                Link("Terms of Use", destination: termsURL)
                            }
                            if let privacyURL = URL(string: "https://memoryaisle.app/privacy") {
                                Link("Privacy Policy", destination: privacyURL)
                            }
                        }
                        .font(Typography.label)
                        .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.5))
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

    // MARK: - CTA State

    /// The CTA always shows "Start Pro" (or "Processing…" during a
    /// purchase) so the paywall renders cleanly regardless of whether
    /// StoreKit has finished fetching products yet. The tap handler
    /// takes care of the "products not loaded yet" case on its own.
    private var ctaTitle: String {
        isPurchasing ? "Processing..." : "Start Pro"
    }

    private var ctaAccessibility: String {
        isPurchasing ? "Processing purchase" : "Start Pro subscription"
    }

    // MARK: - Purchase

    /// Attempts the purchase. If StoreKit hasn't loaded the product yet
    /// (slow network, fast-tapping user, or a temporarily unavailable
    /// App Store Connect entry), this retries `loadProducts()` first,
    /// then falls through to the purchase. If the product is still
    /// unavailable after the retry, surfaces the error alert so the
    /// user gets feedback instead of a dead button.
    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        if subscriptionManager.products.isEmpty {
            await subscriptionManager.loadProducts()
        }

        guard !subscriptionManager.products.isEmpty else {
            showError = true
            return
        }

        do {
            let success = try await subscriptionManager.purchase()
            if success {
                HapticManager.success()
                dismiss()
            }
            // success == false here means userCancelled or pending —
            // both are silent on purpose so the user isn't yelled at
            // for dismissing Apple's confirmation sheet.
        } catch {
            showError = true
        }
    }
}
