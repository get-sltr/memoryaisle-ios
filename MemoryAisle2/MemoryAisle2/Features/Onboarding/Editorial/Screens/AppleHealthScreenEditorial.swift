import SwiftUI

/// Screen 07 — Apple Health permission. Sits before `WeightScreen` so a
/// successful connect can prefill `profile.weightLbs` from HealthKit's
/// latest reading; the user still gets to confirm or override on Screen 08.
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
    @State private var phase: ConnectPhase = .initial

    /// Tracks the connect attempt's outcome locally so the screen can
    /// react to iOS's silent re-prompt behaviour: once the user has made
    /// a decision (granted OR denied), `requestAuthorization` returns
    /// without showing the system sheet, so we have to surface the
    /// result in our own UI instead of advancing blindly.
    private enum ConnectPhase: Equatable {
        case initial          // first view of the screen
        case connecting       // request in flight
        case denied           // request returned but no data — denied or no samples
    }

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

                switch phase {
                case .connecting:
                    ProgressView()
                        .tint(Theme.Editorial.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                case .initial:
                    OnboardingPrimaryButton(title: "CONNECT", action: connect)
                case .denied:
                    deniedActions
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

    // MARK: - Subviews

    private var deniedActions: some View {
        VStack(spacing: 10) {
            Text("APPLE HEALTH DIDN'T SHARE A WEIGHT. OPEN SETTINGS TO TURN ON BODY MEASUREMENTS, OR CONTINUE WITHOUT.")
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            OnboardingPrimaryButton(title: "OPEN SETTINGS", action: {
                healthKit.openSettings()
            })

            Button(action: {
                HapticManager.light()
                onContinue()
            }) {
                Text("CONTINUE WITHOUT")
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(1.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Connect

    private func connect() {
        Task {
            phase = .connecting
            await healthKit.requestAuthorization()
            if let weight = healthKit.latestWeight {
                profile.weightLbs = weight
                HapticManager.success()
                onContinue()
            } else {
                // iOS won't reprompt once a decision has been recorded, so a
                // silent zero-result here means the user needs to enable in
                // Settings. Keep them on this screen and surface the path.
                phase = .denied
                HapticManager.light()
            }
        }
    }
}
