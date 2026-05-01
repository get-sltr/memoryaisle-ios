import StoreKit
import SwiftUI

struct PaywallView: View {
    var mode: MAMode = .auto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var showPending = false
    @State private var selectedProductID: String = SubscriptionManager.proAnnualID

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    topBar
                    hero.padding(.top, 4)
                    HairlineDivider().opacity(0.5)
                    PaywallFeatureList()
                    HairlineDivider().opacity(0.5)
                    plans
                    cta
                    legalSection
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, Theme.Editorial.Spacing.pad)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.updateSubscriptionStatus()
        }
        .alert("Purchase failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text("Something went wrong. Please try again.")
        }
        .alert("Purchase pending approval", isPresented: $showPending) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your purchase is awaiting approval. You'll get Pro access automatically once it's approved, usually within a few minutes for Family Sharing or after your bank confirms.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.Editorial.onSurface)

            Text("MemoryAisle Pro")
                .font(Theme.Editorial.Typography.displayHero())
                .foregroundStyle(Theme.Editorial.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("LOSE FAT · KEEP MUSCLE")
                .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                .tracking(3.2)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 12) {
            PaywallPlanCard(
                title: "Annual",
                priceText: priceFor(SubscriptionManager.proAnnualID, fallback: "$49.99"),
                periodLine: "Auto-renews yearly \u{00b7} ~$0.96/week",
                badge: "Best value",
                savings: "Save 58% vs monthly",
                isSelected: selectedProductID == SubscriptionManager.proAnnualID,
                onTap: {
                    HapticManager.selection()
                    selectedProductID = SubscriptionManager.proAnnualID
                }
            )
            PaywallPlanCard(
                title: "Monthly",
                priceText: priceFor(SubscriptionManager.proMonthlyID, fallback: "$9.99"),
                periodLine: "Auto-renews monthly",
                badge: nil,
                savings: nil,
                isSelected: selectedProductID == SubscriptionManager.proMonthlyID,
                onTap: {
                    HapticManager.selection()
                    selectedProductID = SubscriptionManager.proMonthlyID
                }
            )
        }
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 16) {
            Button {
                guard !isPurchasing else { return }
                Task { await handlePurchase() }
            } label: {
                Text(ctaTitle)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .tracking(0.5)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ctaAccessibility)

            Button {
                Task { await subscriptionManager.restore() }
            } label: {
                Text("Restore purchase".uppercased())
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore previous purchase")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 10) {
            Text(legalCopy)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 18) {
                legalLink("Terms of Use", urlString: "https://memoryaisle.app/terms")
                legalLink("Privacy Policy", urlString: "https://memoryaisle.app/privacy")
            }
        }
        .padding(.top, 6)
    }

    private func legalLink(_ title: String, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .underline()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - CTA copy

    private var ctaTitle: String {
        isPurchasing ? "Processing..." : "Start Pro"
    }

    private var ctaAccessibility: String {
        isPurchasing ? "Processing purchase" : "Start Pro subscription"
    }

    // MARK: - Purchase

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
            let outcome = try await subscriptionManager.purchase(
                productID: selectedProductID,
                appAccountToken: CognitoAuthManager.currentUserUUID()
            )
            switch outcome {
            case .success:
                HapticManager.success()
                dismiss()
            case .pending:
                showPending = true
            case .cancelled:
                break
            case .productUnavailable, .unknown:
                showError = true
            }
        } catch {
            showError = true
        }
    }

    // MARK: - Helpers

    private func priceFor(_ productID: String, fallback: String) -> String {
        subscriptionManager.products
            .first(where: { $0.id == productID })?.displayPrice ?? fallback
    }

    private var legalCopy: String {
        let fallback = selectedProductID == SubscriptionManager.proMonthlyID ? "$9.99" : "$49.99"
        let price = priceFor(selectedProductID, fallback: fallback)
        return SubscriptionManager.legalCopy(productID: selectedProductID, displayPrice: price)
    }
}
