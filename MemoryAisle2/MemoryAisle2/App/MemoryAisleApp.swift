import SwiftData
import SwiftUI
import UIKit

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

        // The reviewer-bypass path was removed in 1.0.3 — its UserDefaults
        // keys are dead state now. Wipe them on every launch so devices
        // that hit the previous build can't carry a stale Pro override
        // forward. Idempotent: removeObject on a missing key is a no-op.
        UserDefaults.standard.removeObject(forKey: "ma_is_app_reviewer_v1")
        UserDefaults.standard.removeObject(forKey: "ma_review_seed_done_v1")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .buttonStyle(.plain)
                .environment(appState)
                .environment(subscriptionManager)
                .environment(miraUsage)
                .environment(barcodeUsage)
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
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @State private var hasSeenWelcome = UserDefaults.standard.bool(forKey: "ma_seen_welcome")
    @State private var container: ModelContainer = Self.buildInitialContainer()

    /// Resolves the right ModelContainer for whoever is currently signed
    /// in (or the anonymous one if nobody is). Called at launch and again
    /// whenever auth state changes, so the per-user store file is always
    /// the one queries see.
    private static func buildInitialContainer() -> ModelContainer {
        let id = UserDataContainer.currentIdentifier()
        if let c = try? UserDataContainer.make(for: id) { return c }
        if let c = try? UserDataContainer.make(for: nil) { return c }
        preconditionFailure("Failed to build any SwiftData container at launch")
    }

    private var isOnboarded: Bool {
        appState.hasCompletedOnboarding || (profiles.first?.hasCompletedOnboarding == true)
    }

    var body: some View {
        Group {
            if !hasSeenWelcome {
                welcomeScreen
            } else {
                switch appState.authStatus {
                case .unknown:
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
        }
        .modelContainer(container)
        .onAppear {
            if profiles.first?.hasCompletedOnboarding == true {
                appState.hasCompletedOnboarding = true
            }
            if hasSeenWelcome {
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
        .onChange(of: appState.authStatus) { _, _ in
            rebuildContainerForCurrentUser()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else { return }
            pushOnBackground()
        }
    }

    /// Rebuilds the SwiftData container to match the currently signed-in
    /// user (or anonymous if none). Triggered when auth state transitions
    /// so a new sign-in, sign-out, or account switch never leaves the
    /// previous user's data visible to the next user. Nothing is
    /// deleted — each user's container file persists on disk; we just
    /// swap which one the app is reading from.
    private func rebuildContainerForCurrentUser() {
        let id = UserDataContainer.currentIdentifier()
        if let newContainer = try? UserDataContainer.make(for: id) {
            container = newContainer
        }
    }

    /// Best-effort push of local syncable state when the app moves to
    /// the background. iOS only gives us a few seconds before suspension,
    /// so `beginBackgroundTask` buys us up to ~30s to finish. If iOS
    /// kills us mid-push the next sign-out or next backgrounding catches
    /// up — logs aren't lost, just delayed. Respects the `CloudSyncable`
    /// allowlist so Safe Space never leaves the device.
    private func pushOnBackground() {
        guard let email = CognitoAuthManager.currentEmail(), !email.isEmpty else { return }
        let capturedContainer = container

        Task { @MainActor in
            let holder = BackgroundTaskHolder()
            holder.id = UIApplication.shared.beginBackgroundTask(withName: "cloud-sync-push") {
                holder.endIfNeeded()
            }
            let context = ModelContext(capturedContainer)
            await CloudSyncManager().pushAll(userId: email, modelContext: context)
            holder.endIfNeeded()
        }
    }

    // MARK: - Welcome Screen (shows once, before sign in)

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingLogo(size: 220)
                .shadow(color: Color.violet.opacity(0.4), radius: 40, y: 10)

            Text("Welcome to")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.top, 32)

            Text("MemoryAisle")
                .font(.system(size: 34, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(1)
                .padding(.top, 4)

            Text("Smarter groceries. Better nutrition.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 12)

            Spacer()

            Button {
                HapticManager.medium()
                UserDefaults.standard.set(true, forKey: "ma_seen_welcome")
                withAnimation(.easeIn(duration: 0.5)) {
                    hasSeenWelcome = true
                }
                Task {
                    let auth = CognitoAuthManager()
                    await auth.restoreSession()
                    if auth.isSignedIn {
                        appState.authStatus = .signedIn
                    } else {
                        appState.authStatus = .signedOut
                    }
                }
            } label: {
                Text("Enter")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule().fill(Color.violet.opacity(0.25))
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background(for: scheme).ignoresSafeArea())
    }
}

/// Wraps a `UIBackgroundTaskIdentifier` so the expiration handler and
/// the completion path share one source of truth. Main-actor isolated
/// because `UIApplication.endBackgroundTask` must be called from the
/// main thread.
@MainActor
private final class BackgroundTaskHolder {
    var id: UIBackgroundTaskIdentifier = .invalid

    func endIfNeeded() {
        guard id != .invalid else { return }
        let toEnd = id
        id = .invalid
        UIApplication.shared.endBackgroundTask(toEnd)
    }
}
