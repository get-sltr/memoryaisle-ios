import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var selectedProductID: String = SubscriptionManager.proAnnualID

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

                    // Plan selection (stacked cards)
                    VStack(spacing: 10) {
                        planCard(
                            productID: SubscriptionManager.proAnnualID,
                            title: "Annual",
                            fallbackPrice: "$49.99",
                            periodLine: "per year \u{00b7} ~$0.96/week",
                            badge: "Best value",
                            savings: "Save 58% vs monthly"
                        )
                        planCard(
                            productID: SubscriptionManager.proMonthlyID,
                            title: "Monthly",
                            fallbackPrice: "$9.99",
                            periodLine: "per month",
                            badge: nil,
                            savings: nil
                        )
                    }
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
                        Text(legalCopy)
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

    /// Attempts the purchase of the currently selected plan. If StoreKit
    /// hasn't loaded the product yet (slow network, fast-tapping user,
    /// or a temporarily unavailable App Store Connect entry), this
    /// retries `loadProducts()` first, then falls through. If the
    /// selected product is still unavailable, surfaces the error alert
    /// so the user gets feedback instead of a dead button.
    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        if subscriptionManager.products.isEmpty {
            await subscriptionManager.loadProducts()
        }

        guard subscriptionManager.products.contains(where: { $0.id == selectedProductID }) else {
            showError = true
            return
        }

        do {
            let success = try await subscriptionManager.purchase(
                productID: selectedProductID,
                appAccountToken: CognitoAuthManager.currentUserUUID()
            )
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

    // MARK: - Plan card

    private func planCard(
        productID: String,
        title: String,
        fallbackPrice: String,
        periodLine: String,
        badge: String?,
        savings: String?
    ) -> some View {
        let isSelected = selectedProductID == productID
        let product = subscriptionManager.products.first(where: { $0.id == productID })
        let priceText = product?.displayPrice ?? fallbackPrice

        return Button {
            HapticManager.selection()
            selectedProductID = productID
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title.uppercased())
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)

                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.Accent.primary(for: scheme)))
                        }
                    }

                    Text(priceText)
                        .font(Typography.monoLarge)
                        .foregroundStyle(Theme.Text.primary)

                    Text(periodLine)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))

                    if let savings {
                        Text(savings)
                            .font(Typography.bodySmall)
                            .foregroundStyle(Theme.Accent.primary(for: scheme).opacity(0.7))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                                ? Theme.Accent.primary(for: scheme)
                                : Theme.Border.glass(for: scheme),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Theme.Accent.primary(for: scheme))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Accent.primary(for: scheme).opacity(isSelected ? 0.10 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                            ? Theme.Accent.primary(for: scheme)
                            : Theme.Accent.primary(for: scheme).opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) plan, \(priceText), \(periodLine)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Legal copy

    private var legalCopy: String {
        let fallback = selectedProductID == SubscriptionManager.proMonthlyID ? "$9.99" : "$49.99"
        let price = subscriptionManager.products
            .first(where: { $0.id == selectedProductID })?
            .displayPrice ?? fallback
        return SubscriptionManager.legalCopy(productID: selectedProductID, displayPrice: price)
    }
}
