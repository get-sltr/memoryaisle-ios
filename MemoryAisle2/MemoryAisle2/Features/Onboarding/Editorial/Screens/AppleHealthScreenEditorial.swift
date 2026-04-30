import SwiftUI

/// Screen 15 — Apple Health permission.
///
/// **Production copy preserved verbatim** from the legacy
/// `MiraOnboardingView.appleHealth` step (lines 313 + 159-163). Apple App
/// Review depends on this exact wording — do not edit without re-reading
/// `MiraOnboardingView.swift`'s preserved string.
struct AppleHealthScreenEditorial: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var healthKit = HealthKitManager()
    @State private var isConnecting: Bool = false

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(
                    "In order to track your progress accurately and read your weight and body composition, would you like to connect to Apple Health?",
                    italic: false,
                    size: 22
                )
                .padding(.bottom, 22)

                Spacer(minLength: 8)

                if isConnecting {
                    ProgressView()
                        .tint(Theme.Editorial.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    OnboardingPrimaryButton(title: "CONTINUE", action: {
                        Task {
                            isConnecting = true
                            await healthKit.requestAuthorization()
                            isConnecting = false
                            if let weight = healthKit.latestWeight {
                                profile.weightLbs = weight
                            }
                            HapticManager.success()
                            onContinue()
                        }
                    })
                }

                Text("READ-ONLY ACCESS. MEMORYAISLE READS WEIGHT, LEAN MASS, AND BODY FAT PERCENTAGE FROM APPLE HEALTH. WE NEVER WRITE DATA BACK.")
                    .font(Theme.Editorial.Typography.caps(8, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
            }
        }
    }
}
