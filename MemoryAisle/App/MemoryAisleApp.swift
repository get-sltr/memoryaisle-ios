import SwiftData
import SwiftUI

@main
struct MemoryAisleApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(for: [
                    UserProfile.self,
                    NutritionLog.self,
                    SymptomLog.self
                ])
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]

    private var isOnboarded: Bool {
        appState.hasCompletedOnboarding || (profiles.first?.hasCompletedOnboarding == true)
    }

    var body: some View {
        Group {
            if isOnboarded {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if profiles.first?.hasCompletedOnboarding == true {
                appState.hasCompletedOnboarding = true
            }
        }
    }
}
