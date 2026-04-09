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
}
