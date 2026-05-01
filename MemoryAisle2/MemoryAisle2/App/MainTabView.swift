import StoreKit
import SwiftData
import SwiftUI

/// Editorial app shell. Owns the gradient + fireflies, the 5-tab bottom
/// bar, the Day/Night mode toggle, and the wordmark menu sheet.
///
/// Tab routing:
///   .today / .meals  → editorial content under the masthead
///   .scan / .mira    → existing feature views shown as full-screen covers
///   .reflect         → existing reflection view, paywall-gated for free users
struct MainTabView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var futurePlans: [MealPlan]

    @State private var selectedTab: MATab = .today
    @State private var activeSheet: MainSheet?
    @State private var hasRunBackfillCheck = false

    private var isPro: Bool { subscriptionManager.tier == .pro }
    private var profile: UserProfile? { profiles.first }
    /// Day/Night follows the user's setting in Settings; `nil` falls back to
    /// the time-of-day auto rule. The toggle moved off the home masthead
    /// so editorial surfaces stay focused on content.
    private var mode: MAMode { appState.effectiveAppearanceMode }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            tabContent
                .padding(.bottom, 80) // room for the floating tab bar

            VStack {
                Spacer()
                MATabBar(
                    selection: $selectedTab,
                    onSelect: handleTabTap
                )
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea(.keyboard)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            runOnceOnLaunch()
        }
        .onChange(of: appState.pendingMiraPrompt) { _, newValue in
            // Dashboard's "Tell Me More" handler queues a prompt here; flip
            // the bar to MIRA so the tab can drain it. MiraTabView clears.
            if newValue != nil {
                selectedTab = .mira
            }
        }
    }

    // MARK: - Launch hooks

    /// Runs once per app launch on first appearance of the editorial shell.
    /// Sweeps orphaned generation jobs (those left "running" by a prior
    /// session that was killed) and triggers backfill for existing users
    /// who have no plans for the upcoming week.
    private func runOnceOnLaunch() {
        guard !hasRunBackfillCheck else { return }
        hasRunBackfillCheck = true

        let orchestrator = WeeklyMealPlanOrchestrator()
        orchestrator.reconcileOrphanedJobs(in: modelContext)

        guard FeatureFlags.shared.weeklyMealBackfillEnabled,
              let profile,
              profile.hasCompletedOnboarding else { return }

        if hasPlanInUpcomingWeek() { return }

        let outcome = orchestrator.startWeekly(
            profile: profile,
            giTriggers: [],
            pantryItems: [],
            startDate: .now,
            days: 7,
            trigger: .backfill,
            isPro: isPro,
            context: modelContext
        )
        if case .rejected(let reason) = outcome {
            appState.lastWeeklyGenRejection = reason
        }
    }

    private func hasPlanInUpcomingWeek() -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return true }
        return futurePlans.contains { plan in
            plan.isActive && plan.date >= start && plan.date < end
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .today:
            TodayDashboardView(
                mode: mode,
                onTapWordmark: openMenu,
                onPresentScan: { activeSheet = .scanMode($0) }
            )
        case .meals:
            MealsView(mode: mode, onTapWordmark: openMenu)
        case .mira:
            MiraTabView(mode: mode, onTapWordmark: openMenu)
        case .scan, .reflect:
            // SCAN and REFLECT trigger sheets via handleTabTap and never land
            // here, but if the state ever desyncs we fall back to Today so
            // users aren't stuck on a blank gradient.
            TodayDashboardView(
                mode: mode,
                onTapWordmark: openMenu,
                onPresentScan: { activeSheet = .scanMode($0) }
            )
        }
    }

    // MARK: - Tab tap handling

    private func handleTabTap(_ tab: MATab) {
        switch tab {
        case .today, .meals, .mira:
            // selection binding inside MATabBar already updated; these are
            // editorial tab content, no sheet needed.
            break
        case .scan:
            activeSheet = .scan
        case .reflect:
            activeSheet = isPro ? .destination(.reflection) : .destination(.subscribe)
        }
    }

    // MARK: - Menu

    private func openMenu() {
        activeSheet = .menu
    }

    // MARK: - Sheet routing

    @ViewBuilder
    private func sheetContent(for sheet: MainSheet) -> some View {
        switch sheet {
        case .menu:
            MenuSheet(
                isPro: isPro,
                onSelect: { dest in handleMenuSelect(dest) },
                onClose: { activeSheet = nil }
            )
        case .scan:
            ScanView()
        case .scanMode(let mode):
            ScanView(initialMode: mode)
        case .mira:
            MiraChatView()
        case .destination(let dest):
            destinationView(dest)
        }
    }

    /// Routes Pro-only menu destinations through the paywall for free users.
    private func gateDestination(_ dest: MenuDestination) -> MenuDestination {
        if !isPro && Self.proGatedDestinations.contains(dest) {
            return .subscribe
        }
        return dest
    }

    private static let proGatedDestinations: Set<MenuDestination> = [.profile, .reflection]

    /// Handles a menu selection. Most rows fall through to a sheet via
    /// `.destination(...)`; a few have side-effect routes (Today pivots
    /// the bottom-bar selection, Notifications deep-links into iOS
    /// Settings) and exit without presenting a sheet.
    private func handleMenuSelect(_ dest: MenuDestination) {
        switch dest {
        case .today:
            // Pivot the tab bar instead of opening a sheet — Today is
            // already a top-level tab, the menu entry is a shortcut.
            activeSheet = nil
            selectedTab = .today
        case .notifications:
            // No in-app notifications pane yet; deep-link to the iOS
            // Settings page for this app where the user can manage
            // permissions and toggles.
            activeSheet = nil
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .medications:
            // Dedicated MedicationView — operational data (provider,
            // pharmacy, refill) lives there. The Journey page keeps a
            // summary block but doesn't own this surface.
            activeSheet = .destination(.medications)
        case .foodAllergies:
            // No focused screen yet — route to Journey until one is built.
            activeSheet = .destination(.profile)
        case .emailProfile:
            // Account info lives at the top of the Settings sheet
            // (ProfileView). Route there.
            activeSheet = .destination(.settings)
        default:
            activeSheet = .destination(gateDestination(dest))
        }
    }

    @ViewBuilder
    private func destinationView(_ dest: MenuDestination) -> some View {
        switch dest {
        case .profile:        JourneyView()
        case .progress:       JourneyView()
        case .groceryList:    GroceryListScreen()
        case .recipes:        RecipesView()
        case .calendar:       CalendarView()
        case .pantry:         PantryView()
        case .safeSpace:      SafeSpaceView()
        case .reflection:     ReflectionView()
        case .scan:           ScanView()
        case .scanReceipt:    ReceiptScannerView()
        case .favorites:      FavoritesView()
        case .medications:    MedicationView()
        case .mira:           MiraChatView()
        case .subscribe:      PaywallView()
        case .proBenefits:    ProBenefitsView()
        case .settings:       EditorialSettingsView()
        // Routed via handleMenuSelect side-effects, never reach the sheet:
        case .today, .notifications, .foodAllergies, .emailProfile:
            EmptyView()
        }
    }
}

enum MainSheet: Identifiable, Hashable {
    case menu
    case scan
    case scanMode(ScanView.ScanMode)
    case mira
    case destination(MenuDestination)

    var id: String {
        switch self {
        case .menu:                "menu"
        case .scan:                "scan"
        case .scanMode(let m):     "scan-\(m)"
        case .mira:                "mira"
        case .destination(let d):  "dest-\(d.rawValue)"
        }
    }
}
