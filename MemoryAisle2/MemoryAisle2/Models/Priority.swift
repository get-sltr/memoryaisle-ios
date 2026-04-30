import Foundation

/// Top-of-mind priorities the user ranks (top 3, ordered) on Screen 02 of
/// the editorial onboarding. Drives branch-soft routing: if `.glp1Appetite`
/// appears in the user's selected priorities, the GLP-1 path activates
/// (Screens 11 to 14). Otherwise the flow skips to Screen 15 (Apple Health).
///
/// Distinct from `Worry` — Worry captures specific GLP-1 side-effect concerns
/// that drive `ProductMode.sensitiveStomach`. Priority is broader life-goal
/// framing for routing and personalization signal.
enum Priority: String, Codable, CaseIterable, Sendable, Identifiable {
    case glp1Appetite     = "I'm on a GLP-1 or managing appetite changes"
    case weightLoss       = "I want help losing weight"
    case mealPlanning     = "I want easier meal planning"
    case grocery          = "I want grocery help"
    case nutritionHabits  = "I want better nutrition habits"
    case healthGoal       = "I want support for a health goal"

    var id: String { rawValue }
    var displayName: String { rawValue }
}
