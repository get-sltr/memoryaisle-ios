import SwiftUI

/// Screen 02 — Top-3 priority ranking.
///
/// Tap a choice to add it to the user's priority list (in tap order).
/// Tap again to remove. The first selection appears as rank 1, second
/// as rank 2, third as rank 3. Continue button enables once the user
/// has at least one priority — three is the encouraged ideal but we
/// don't lock the gate at three to avoid frustrating users who feel
/// strongly about only one or two.
struct PrioritiesScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var canContinue: Bool { !profile.priorities.isEmpty }

    private var continueLabel: String {
        switch profile.priorities.count {
        case 0:  "PICK AT LEAST ONE"
        case 1:  "CONTINUE WITH 1 PRIORITY"
        default: "CONTINUE WITH \(profile.priorities.count) PRIORITIES"
        }
    }

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "What brings you to"),
                    QuestionLine(text: "MemoryAisle?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Tap your top three in order. The first one matters most.")
                    .padding(.bottom, 18)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Priority.allCases) { priority in
                            OnboardingChoice(
                                title: priority.displayName,
                                isSelected: profile.priorities.contains(priority),
                                rank: rank(for: priority),
                                action: { toggle(priority) }
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                OnboardingPrimaryButton(
                    title: continueLabel,
                    disabled: !canContinue,
                    action: onContinue
                )
                .padding(.top, 14)
            }
        }
    }

    private func rank(for priority: Priority) -> Int? {
        guard let idx = profile.priorities.firstIndex(of: priority) else { return nil }
        return idx + 1
    }

    private func toggle(_ priority: Priority) {
        HapticManager.light()
        if let idx = profile.priorities.firstIndex(of: priority) {
            profile.priorities.remove(at: idx)
        } else if profile.priorities.count < 3 {
            profile.priorities.append(priority)
        }
        // 4th+ selections are silently rejected — user must remove one to add another.
    }
}
