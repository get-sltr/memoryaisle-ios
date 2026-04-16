import SwiftUI

/// Inline card on `BodyStatsScreen` that asks permission for HealthKit
/// and, on success, hands the user's most recent weight sample back to
/// the caller via `onWeightPulled`. Placed in onboarding so the
/// HealthKit surface is visible at the moment weight is being collected,
/// instead of hiding at the bottom of the Progress tab.
///
/// The card owns its own `HealthKitManager` and state machine so the
/// parent screen stays focused on body-stats input. The caller decides
/// whether to accept the pulled weight (e.g., skip if the user has
/// already typed a value manually).
struct OnboardingHealthKitAutofillCard: View {
    let onWeightPulled: (Double) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var healthKit = HealthKitManager()
    @State private var state: AutofillState = .idle

    private enum AutofillState {
        case idle, loading, connected, denied
    }

    var body: some View {
        Button {
            Task { await connect() }
        } label: {
            HStack(spacing: 12) {
                iconCap
                textStack
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        state == .connected
                            ? Color.violet.opacity(0.25)
                            : Theme.Border.glass(for: scheme),
                        lineWidth: Theme.glassBorderWidth
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .opacity(state == .denied ? 0.6 : 1.0)
        .animation(Theme.Motion.spring, value: state)
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var iconCap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.violet.opacity(0.12))
                .frame(width: 40, height: 40)

            Image(systemName: "heart.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.violet)
        }
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .idle:
            Text("Connect")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.violet)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.violet.opacity(0.14)))
        case .loading:
            ProgressView()
                .controlSize(.small)
                .tint(Color.violet)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.violet)
        case .denied:
            Text("Not now")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
    }

    // MARK: - Copy

    private var title: String {
        switch state {
        case .idle, .loading: "Autofill from Apple Health"
        case .connected: "Pulled from Apple Health"
        case .denied: "Apple Health not connected"
        }
    }

    private var subtitle: String {
        switch state {
        case .idle: "Let Mira pull your latest weight"
        case .loading: "Connecting..."
        case .connected: "Your weight landed below"
        case .denied: "You can connect later from Profile"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: "Autofill weight from Apple Health"
        case .loading: "Connecting to Apple Health"
        case .connected: "Weight autofilled from Apple Health"
        case .denied: "Apple Health not connected"
        }
    }

    // MARK: - Action

    /// Requests read-only HealthKit authorization. On success, hands the
    /// most recent weight sample to `onWeightPulled` inside a spring
    /// animation so the parent field visibly accepts the value. On deny,
    /// parks the card in a dimmed "Not now" state so the user can still
    /// see HealthKit exists but can't re-trigger the permission sheet
    /// from here.
    private func connect() async {
        withAnimation(Theme.Motion.spring) {
            state = .loading
        }
        HapticManager.light()

        await healthKit.requestAuthorization()

        if healthKit.isAuthorized {
            let pulledWeight = healthKit.latestWeight
            withAnimation(Theme.Motion.spring) {
                state = .connected
                if let pulledWeight {
                    onWeightPulled(pulledWeight)
                }
            }
            HapticManager.success()
        } else {
            withAnimation(Theme.Motion.spring) {
                state = .denied
            }
        }
    }
}
