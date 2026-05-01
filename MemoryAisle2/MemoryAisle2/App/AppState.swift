import SwiftUI

@Observable
final class AppState {

    enum AuthStatus {
        case unknown
        case signedOut
        case signedIn
    }

    enum Tab: Int, CaseIterable {
        case home
        case recipes
        case scan
        case safeSpace
        case progress

        var title: String {
            switch self {
            case .home: "Home"
            case .recipes: "Recipes"
            case .scan: "Scan"
            case .safeSpace: "Safe Space"
            case .progress: "Me"
            }
        }

        var icon: String {
            switch self {
            case .home: "cart.fill"
            case .recipes: "book.fill"
            case .scan: "barcode.viewfinder"
            case .safeSpace: "lock.shield.fill"
            case .progress: "person.fill"
            }
        }
    }

    var authStatus: AuthStatus = .unknown
    var hasCompletedOnboarding = false
    var selectedTab: Tab = .home
    var homePath = NavigationPath()
    var recipesPath = NavigationPath()
    var progressPath = NavigationPath()
    /// Last reason a weekly meal-plan generation was rejected before any
    /// Bedrock call was issued (flag off, quota exhausted, etc.). MealsView
    /// reads this so the user gets a hint instead of staring at a missing plan.
    var lastWeeklyGenRejection: WeeklyMealPlanOrchestrator.RejectionReason?

    /// One-shot prompt queued by another surface (currently the Today
    /// dashboard's "Tell Me More" follow-up card) for `MiraTabView` to send
    /// as the next user turn. The shell flips `selectedTab` to `.mira` when
    /// this is set; `MiraTabView` consumes and clears it. Treat as
    /// fire-and-forget — value is non-nil only between set and consume.
    var pendingMiraPrompt: String?
}
