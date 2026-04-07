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
        case mira
        case progress

        var title: String {
            switch self {
            case .home: "Home"
            case .recipes: "Recipes"
            case .scan: "Scan"
            case .mira: "Mira"
            case .progress: "Progress"
            }
        }

        var icon: String {
            switch self {
            case .home: "house.fill"
            case .recipes: "book.fill"
            case .scan: "barcode.viewfinder"
            case .mira: "waveform"
            case .progress: "chart.line.uptrend.xyaxis"
            }
        }
    }

    var authStatus: AuthStatus = .unknown
    var hasCompletedOnboarding = false
    var selectedTab: Tab = .home
    var homePath = NavigationPath()
    var recipesPath = NavigationPath()
    var miraPath = NavigationPath()
    var progressPath = NavigationPath()
}
