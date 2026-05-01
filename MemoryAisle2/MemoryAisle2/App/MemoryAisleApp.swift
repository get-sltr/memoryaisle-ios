import SwiftData
import SwiftUI

@main
struct MemoryAisleApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var subscriptionManager = SubscriptionManager()
    @State private var miraUsage = MiraUsageTracker()
    @State private var barcodeUsage = BarcodeUsageTracker()

    init() {
        // iOS does not create Library/Application Support automatically.
        // SwiftData writes its store there, so pre-create the directory to
        // avoid a noisy CoreData "Failed to create file" recovery on first launch.
        _ = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .buttonStyle(.plain)
                .environment(appState)
                .environment(subscriptionManager)
                .environment(miraUsage)
                .environment(barcodeUsage)
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
                    ProviderReport.self,
                    SavedRecipe.self,
                    MealGenerationJob.self
                ])
                // Re-query StoreKit whenever the app becomes active so a
                // subscription purchased on another device, a cancellation
                // processed while backgrounded, or an Apple ID switch is
                // reflected without requiring a relaunch.
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await subscriptionManager.updateSubscriptionStatus() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    /// Returns the profile belonging to the currently signed-in user via
    /// strict `userId == cognitoSub` match. Returns nil when no profile
    /// matches; caller routes to onboarding.
    ///
    /// Pre-migration UserProfile rows have `userId == nil` and are
    /// effectively orphaned by this scoping — by design, so a fresh
    /// account on a shared device cannot inherit a previous tester's
    /// onboarded state. Those rows still live in SwiftData (data
    /// preservation rule) but are no longer surfaced via routing until
    /// re-claimed through the auth-rewrite work.
    private func currentUserProfile() -> UserProfile? {
        guard let currentUserId = appState.cognitoUserId else { return nil }
        return profiles.first(where: { $0.userId == currentUserId })
    }

    private var isOnboarded: Bool {
        // Trust the in-session flag first — `completeOnboarding` flips it
        // synchronously the moment a fresh user finishes the flow, so the
        // routing flips without waiting for the @Query to re-publish the
        // newly-inserted profile. The flag is sign-out-reset everywhere
        // (ProfileView, EditorialSettingsView) so a stale value can't leak
        // across accounts. Falls back to the userId-scoped profile lookup
        // for returning users on a fresh launch (flag defaults to false).
        if appState.hasCompletedOnboarding { return true }
        return currentUserProfile()?.hasCompletedOnboarding == true
    }

    var body: some View {
        Group {
            switch appState.authStatus {
            case .unknown:
                ZStack {
                    Color.indigoBlack.ignoresSafeArea()
                    MiraWaveform(state: .thinking, size: .hero)
                        .frame(height: 60)
                }
            case .signedOut:
                // Editorial auth flow. Owns the first-run welcome gate
                // internally via the `ma_seen_welcome` UserDefault, so
                // RootView no longer needs a pre-auth welcome branch.
                MAAuthFlow()
            case .signedIn:
                if isOnboarded {
                    MainTabView()
                } else {
                    OnboardingFlow()
                }
            }
        }
        .onAppear {
            Task {
                let auth = CognitoAuthManager()
                await auth.restoreSession()
                appState.cognitoUserId = auth.userId
                appState.authStatus = auth.isSignedIn ? .signedIn : .signedOut
            }
        }
    }
}
