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
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var showManageSubscriptions = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    hero
                    featureList
                    summaryCard
                    manageButton
                    legalFootnote
                    Spacer(minLength: 40)
                }
            }
        }
        .themeBackground()
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 16) {
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 60)

            Text("MemoryAisle Pro")
                .font(Typography.serifLarge)
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .tracking(0.3)

            Text("Everything you have unlocked.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
        }
        .padding(.top, 16)
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

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 10) {
            Text("Your Plan")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)

            Text("$49.99")
                .font(Typography.monoLarge)
                .foregroundStyle(Theme.Text.primary)

            Text("per year \u{00b7} auto-renews annually")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
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

    private var legalFootnote: some View {
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
    }
}
