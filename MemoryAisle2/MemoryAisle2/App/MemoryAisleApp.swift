import SwiftData
import SwiftUI

@main
struct MemoryAisleApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                // TODO: Replace with MiraIntroView when onboarding is built
                MainTabView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
