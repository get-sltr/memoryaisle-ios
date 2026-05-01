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

    /// Cognito sub for the currently signed-in user. Populated by
    /// `RootView.onAppear` after `restoreSession()` resolves. Used by the
    /// onboarding gate to scope `UserProfile` lookup to the right account
    /// (a shared device that signed in user A and then user B should not
    /// treat user A's stale profile as user B's onboarded state). Nil
    /// while the auth status is `.unknown` or `.signedOut`.
    var cognitoUserId: String?
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

    /// User's explicit choice for the editorial Day/Night gradient. `nil`
    /// means follow the time of day (`MAMode.auto`). The previous design
    /// surfaced a sun/moon toggle on the home masthead — moved into the
    /// Settings sheet so the home stays clean.
    var appearanceMode: MAMode?

    /// Resolved mode that the editorial shell should render. Returns the
    /// user's explicit choice if set, otherwise the time-of-day default.
    var effectiveAppearanceMode: MAMode {
        appearanceMode ?? MAMode.auto
    }
}
