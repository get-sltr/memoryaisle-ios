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
                    SymptomLog.self,
                    PantryItem.self,
                    GIToleranceRecord.self,
                    MealPlan.self,
                    Meal.self,
                    FoodItem.self,
                    GroceryList.self,
                    MedicationProfile.self,
                    TrainingSession.self,
                    BodyComposition.self,
                    ProviderReport.self
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
            switch appState.authStatus {
            case .unknown:
                // Splash / loading
                ZStack {
                    Color.indigoBlack.ignoresSafeArea()
                    MiraWaveform(state: .thinking, size: .hero)
                        .frame(height: 60)
                }
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                if isOnboarded {
                    MainTabView()
                } else {
                    OnboardingFlow()
                }
            }
        }
        .onAppear {
            if profiles.first?.hasCompletedOnboarding == true {
                appState.hasCompletedOnboarding = true
            }
            // Check for existing session
            Task {
                let auth = CognitoAuthManager()
                await auth.restoreSession()
                if auth.isSignedIn {
                    appState.authStatus = .signedIn
                } else {
                    appState.authStatus = .signedOut
                }
            }
        }
    }
}
