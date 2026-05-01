import SwiftUI

/// Screen 17 — All set / personalized plan ready. Shows a small summary
/// derived from what the user told us during onboarding. "Take me home"
/// fires the timed transition (Screen 18).
struct ReadyScreenEditorial: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: nil) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingMiraMark()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 22)

                OnboardingQuestion(lines: [
                    QuestionLine(text: "All set\(nameSuffix),"),
                    QuestionLine(text: "let's begin.", italic: true)
                ], size: 32)
                .padding(.bottom, 14)

                if !summaryLines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(summaryLines, id: \.self) { line in
                            Text(line)
                                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                                .tracking(1.8)
                                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.9))
                        }
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
                    }
                    .padding(.bottom, 14)
                }

                OnboardingHelper(text: "I'll keep learning as we go. Anything you told me, your goals, preferences, medication, what to leave alone, you can change anytime in Settings.")

                Spacer(minLength: 24)

                OnboardingPrimaryButton(title: "TAKE ME HOME", action: onContinue)
            }
        }
    }

    private var nameSuffix: String {
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : ", \(trimmed)"
    }

    private var summaryLines: [String] {
        var lines: [String] = []

        if !profile.priorities.isEmpty {
            let priorityCaps = profile.priorities.map { priorityShorthand($0) }.joined(separator: " · ")
            lines.append("PRIORITIES · \(priorityCaps)")
        }

        if let med = profile.medication {
            let dose = profile.doseAmount.map { " \($0)" } ?? ""
            lines.append("PLAN · \(med.rawValue.uppercased())\(dose.uppercased())")
        }

        if let weight = profile.weightLbs {
            let goal = profile.goalWeightLbs.map { " → \(Int($0))" } ?? ""
            lines.append("GOAL · \(Int(weight))\(goal) LB")
        }

        return lines
    }

    private func priorityShorthand(_ priority: Priority) -> String {
        switch priority {
        case .glp1Appetite:    "GLP-1"
        case .weightLoss:      "WEIGHT"
        case .mealPlanning:    "PLAN"
        case .grocery:         "GROCERY"
        case .nutritionHabits: "HABITS"
        case .healthGoal:      "HEALTH"
        }
    }
}
