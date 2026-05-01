import SwiftUI

/// Screen 18 — Personalization transition. 3-second hold with three
/// cross-fading lines, then auto-advances by firing `onComplete`. The
/// `onComplete` closure routes back to `OnboardingFlow.completeOnboarding()`
/// which writes the UserProfile and kicks off the WeeklyMealPlanOrchestrator.
struct PersonalizationTransitionScreen: View {
    let progress: Double
    let onComplete: () -> Void

    private let lines = [
        ("Gathering your", "information", "...".isEmpty ? "" : "..."),
        ("Curating your", "plan", "..."),
        ("Tailoring it to your", "goals", ".")
    ]

    @State private var visibleIndex: Int = 0

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: nil) {
            VStack(spacing: 32) {
                Spacer()

                OnboardingMiraMark()

                ZStack {
                    ForEach(0..<lines.count, id: \.self) { idx in
                        line(at: idx)
                            .opacity(visibleIndex == idx ? 1 : 0)
                            .offset(y: visibleIndex == idx ? 0 : 8)
                            .animation(.easeInOut(duration: 0.4), value: visibleIndex)
                    }
                }
                .frame(height: 70)
                .frame(maxWidth: .infinity)

                Spacer()

                Text("— ONE MOMENT —")
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))
            }
        }
        .task {
            await runTransition()
        }
    }

    @ViewBuilder
    private func line(at index: Int) -> some View {
        let parts = lines[index]
        VStack(spacing: 0) {
            (Text(parts.0 + " ")
                + Text(parts.1)
                    .italic()
                + Text(parts.2)
            )
            .font(.system(size: 22, weight: .regular, design: .serif))
            .foregroundStyle(Theme.Editorial.onSurface)
            .multilineTextAlignment(.center)
        }
    }

    /// Fade through the three lines over ~3 seconds total, then complete.
    /// Step durations: line1 visible ~0.9s, line2 ~0.9s, line3 ~0.9s,
    /// brief breath at the end before handing off to home.
    private func runTransition() async {
        // Line 1 is already visible (visibleIndex == 0 default)
        try? await Task.sleep(for: .milliseconds(900))
        visibleIndex = 1
        try? await Task.sleep(for: .milliseconds(900))
        visibleIndex = 2
        try? await Task.sleep(for: .milliseconds(1200))
        onComplete()
    }
}
