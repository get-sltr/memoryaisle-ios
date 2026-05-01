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

    @State private var mode: MAMode = .auto
    @State private var selectedTab: MATab = .today
    @State private var activeSheet: MainSheet?
    @State private var hasRunBackfillCheck = false

    private var isPro: Bool { subscriptionManager.tier == .pro }
    private var profile: UserProfile? { profiles.first }

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

            VStack {
                HStack {
                    Spacer()
                    modeToggle
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
                Spacer()
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
            HomeView(mode: mode, onTapWordmark: openMenu)
        case .meals:
            MealsView(mode: mode, onTapWordmark: openMenu)
        case .mira:
            MiraTabView(mode: mode, onTapWordmark: openMenu)
        case .scan, .reflect:
            // SCAN and REFLECT trigger sheets via handleTabTap and never land
            // here, but if the state ever desyncs we fall back to Today so
            // users aren't stuck on a blank gradient.
            HomeView(mode: mode, onTapWordmark: openMenu)
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

    // MARK: - Mode toggle

    private var modeToggle: some View {
        Button {
            HapticManager.light()
            withAnimation(.easeInOut(duration: 0.6)) {
                mode = (mode == .day) ? .night : .day
            }
        } label: {
            Text(mode == .day ? "☾" : "☀")
                .font(.system(size: 16))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(10)
                .accessibilityLabel(mode == .day ? "Switch to night mode" : "Switch to day mode")
        }
        .buttonStyle(.plain)
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
                isOnGLP: profile?.medicationModality != nil,
                onSelect: { dest in
                    activeSheet = .destination(gateDestination(dest))
                },
                onClose: { activeSheet = nil }
            )
        case .scan:
            ScanView()
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

    private static let proGatedDestinations: Set<MenuDestination> = [.progress, .reflection]

    @ViewBuilder
    private func destinationView(_ dest: MenuDestination) -> some View {
        switch dest {
        case .profile:     JourneyProfileView()
        case .progress:    ProgressDashboardView()
        case .groceryList: GroceryListScreen(mode: mode)
        case .recipes:     RecipesView()
        case .calendar:    CalendarView(mode: mode)
        case .pantry:      PantryView(mode: mode)
        case .safeSpace:   SafeSpaceView()
        case .reflection:  ReflectionView()
        case .scan:        ScanView()
        case .mira:        MiraChatView()
        case .subscribe:   PaywallView(mode: mode)
        case .proBenefits: ProBenefitsView()
        case .medications: MedicationView(mode: mode)
        case .settings:    ProfileView()
        }
    }
}

enum MainSheet: Identifiable, Hashable {
    case menu
    case scan
    case mira
    case destination(MenuDestination)

    var id: String {
        switch self {
        case .menu:                "menu"
        case .scan:                "scan"
        case .mira:                "mira"
        case .destination(let d):  "dest-\(d.rawValue)"
        }
    }
}
