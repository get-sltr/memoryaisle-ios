import StoreKit
import SwiftUI

/// Pro users' subscription detail screen. Shows what's included in their
/// active subscription, the auto-renewal fine print, and a Manage button
/// that hands off to Apple's native subscription management UI.
///
/// Apple guideline 3.1.2 requires apps with auto-renewable subscriptions
/// to give the user an obvious in-app path to view subscription details
/// and to manage or cancel from within the app.
struct ProBenefitsView: View {
    var mode: MAMode = .auto

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showManageSubscriptions = false

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    featureList
                    summaryCard
                    manageButton
                    legalFootnote
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    doneButton
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    // MARK: - Hero

    private var header: some View {
        VStack(spacing: 16) {
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 60)

            Text("MemoryAisle Pro")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface)
                .multilineTextAlignment(.center)
                .tracking(0.3)

            Text("Everything you have unlocked.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var doneButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Text("DONE")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Features

    private var featureList: some View {
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
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.8))

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.Editorial.onSurface.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 10) {
            Text("Your Plan")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            Text(activePriceText)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface)

            Text(activePeriodText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Editorial.onSurface.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var isActiveMonthly: Bool {
        subscriptionManager.activeProduct?.id == SubscriptionManager.proMonthlyID
    }

    private var activePriceText: String {
        subscriptionManager.activeProduct?.displayPrice
            ?? (isActiveMonthly ? "$9.99" : "$49.99")
    }

    private var activePeriodText: String {
        isActiveMonthly
            ? "per month \u{00b7} auto-renews monthly"
            : "per year \u{00b7} auto-renews annually"
    }

    // MARK: - Manage button

    private var manageButton: some View {
        GlowButton("Manage Subscription") {
            showManageSubscriptions = true
        }
        .accessibilityLabel("Manage subscription, opens Apple's subscription settings")
        .padding(.horizontal, 32)
    }

    // MARK: - Legal footnote (auto-renewal disclosure)

    private var legalCopy: String {
        let activeID = subscriptionManager.activeProduct?.id
            ?? (isActiveMonthly ? SubscriptionManager.proMonthlyID : SubscriptionManager.proAnnualID)
        let price = subscriptionManager.activeProduct?.displayPrice
            ?? (isActiveMonthly ? "$9.99" : "$49.99")
        return SubscriptionManager.legalCopy(productID: activeID, displayPrice: price)
    }

    private var legalFootnote: some View {
        VStack(spacing: 6) {
            Text(legalCopy)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.65))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                if let termsURL = URL(string: "https://memoryaisle.app/terms") {
                    Link("Terms of Use", destination: termsURL)
                }
                if let privacyURL = URL(string: "https://memoryaisle.app/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478).opacity(0.85))
        }
        .padding(.top, 8)
    }
}
