import SwiftUI

struct MiraReadyScreen: View {
    let profile: OnboardingProfile
    let onComplete: () -> Void
    @State private var miraState: MiraState = .thinking
    @State private var showSummary = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MiraWaveform(state: miraState, size: .hero)
                .padding(.bottom, Theme.Spacing.xl)

            if showSummary {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("I've set everything up.")
                        .font(Typography.displaySmall)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    // Summary card
                    GlassCardStrong {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            if let med = profile.medication {
                                summaryRow("Medication", value: med.rawValue)
                            }

                            if let modality = profile.modality {
                                summaryRow("Type", value: modality.displayName)
                            }

                            if !profile.worries.isEmpty {
                                summaryRow("Focus", value: profile.worries.first?.rawValue ?? "")
                            }

                            summaryRow("Training", value: profile.trainingLevel.rawValue)

                            summaryRow("Mode", value: derivedMode)
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    Text("I'll plan your meals around your cycle and make sure every bite counts.")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            if showButton {
                VioletButton("Take me home", icon: "arrow.right") {
                    HapticManager.success()
                    onComplete()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            // Mira "builds" the profile
            withAnimation(Theme.Motion.gentle.delay(1.5)) {
                miraState = .speaking
                showSummary = true
            }
            withAnimation(Theme.Motion.gentle.delay(2.5)) {
                showButton = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(Theme.Motion.gentle) {
                    miraState = .idle
                }
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(Typography.bodyMediumBold)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var derivedMode: String {
        if profile.worries.contains(.nausea) { return ProductMode.sensitiveStomach.rawValue }
        if profile.trainingLevel == .lifts { return ProductMode.musclePreservation.rawValue }
        return ProductMode.everyday.rawValue
    }
}
