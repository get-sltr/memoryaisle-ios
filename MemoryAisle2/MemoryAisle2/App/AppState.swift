import SwiftUI

/// User's measurement-system preference. Storage stays in canonical units
/// (lbs, inches, liters); this only governs display + onboarding input.
enum UnitSystem: String, CaseIterable, Sendable {
    case imperial, metric

    /// Locale-derived default. `Locale.measurementSystem` reports `.metric`
    /// for most non-US locales (UK, EU, AU, NZ), `.us` for the US, and
    /// `.uk` for the UK proper which we treat as metric for body weight
    /// because users there universally use kg/cm in health contexts even
    /// when shop scales still show stones/pounds.
    static var localeDefault: UnitSystem {
        switch Locale.current.measurementSystem {
        case .us:      return .imperial
        case .metric:  return .metric
        case .uk:      return .metric
        default:       return .imperial
        }
    }

    var label: String {
        switch self {
        case .imperial: "IMPERIAL"
        case .metric:   "METRIC"
        }
    }

    var sublabel: String {
        switch self {
        case .imperial: "LBS · INCHES"
        case .metric:   "KG · CM"
        }
    }
}

/// Number-rendering choice for editorial mastheads, week markers, and the
/// day rail. Roman numerals are the editorial default; users outside the
/// pattern (or who simply find roman illegible) can switch to arabic.
enum NumberStyle: String, CaseIterable, Sendable {
    case roman, arabic

    /// Locale-derived default. We default English-language locales to roman
    /// because the editorial pattern was designed around it; everyone else
    /// gets arabic so the masthead reads cleanly in their cultural context.
    static var localeDefault: NumberStyle {
        switch Locale.current.language.languageCode?.identifier {
        case "en": return .roman
        default:   return .arabic
        }
    }

    var label: String {
        switch self {
        case .roman:  "ROMAN"
        case .arabic: "REGULAR"
        }
    }

    var sublabel: String {
        switch self {
        case .roman:  "MMVI · V·VII"
        case .arabic: "07/05/2026"
        }
    }
}

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

    // MARK: - Units + numbers prefs (UserDefaults-backed)
    //
    // Display preferences only — storage stays canonical (lbs/inches/liters).
    // Defaults are locale-derived on first launch (UK/EU/AU → metric; en-locales
    // → roman editorial dates), and the user can flip them in Settings.

    private static let unitSystemKey = "ma_unit_system_v1"
    private static let numberStyleKey = "ma_number_style_v1"

    var unitSystem: UnitSystem = {
        if let raw = UserDefaults.standard.string(forKey: AppState.unitSystemKey),
           let stored = UnitSystem(rawValue: raw) {
            return stored
        }
        return UnitSystem.localeDefault
    }() {
        didSet {
            UserDefaults.standard.set(unitSystem.rawValue, forKey: AppState.unitSystemKey)
        }
    }

    var numberStyle: NumberStyle = {
        if let raw = UserDefaults.standard.string(forKey: AppState.numberStyleKey),
           let stored = NumberStyle(rawValue: raw) {
            return stored
        }
        return NumberStyle.localeDefault
    }() {
        didSet {
            UserDefaults.standard.set(numberStyle.rawValue, forKey: AppState.numberStyleKey)
        }
    }
}
