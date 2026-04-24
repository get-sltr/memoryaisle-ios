import StoreKit
import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.colorScheme) private var scheme
    @State private var activeSheet: MainSheet?

    private var isPro: Bool { subscriptionManager.tier == .pro }

    /// Routes a tapped menu destination through the gate. Pro-only
    /// destinations open the paywall sheet for free users instead of
    /// the real screen, so we never show partial Pro content.
    private func openDestination(_ dest: MenuDestination) {
        if !isPro && Self.proGatedDestinations.contains(dest) {
            activeSheet = .destination(.subscribe)
        } else {
            activeSheet = .destination(dest)
        }
    }

    /// Pro-only destinations. Anything intelligence- or analytics-heavy
    /// lives behind the paywall; the rest of the menu stays free so the
    /// user can still log meals, scan, manage groceries, journal, and
    /// chat with Mira (which has its own per-day quota).
    private static let proGatedDestinations: Set<MenuDestination> = [
        .progress,
        .reflection
    ]

    // Synthetic binding to convert activeSheet into a showMenu binding
    // so HomeView's menu button still works with its existing API.
    private var showMenuBinding: Binding<Bool> {
        Binding(
            get: { activeSheet == .menu },
            set: { newValue in
                if newValue {
                    activeSheet = .menu
                } else if activeSheet == .menu {
                    activeSheet = nil
                }
            }
        )
    }

    var body: some View {
        HomeView(showMenu: showMenuBinding)
            .overlay(alignment: .trailing) {
                MiraFloatingButton {
                    activeSheet = .mira
                }
                .padding(.trailing, 16)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .mira:
                    MiraChatView()
                case .menu:
                    menuSheet
                case .destination(let dest):
                    destinationView(dest)
                }
            }
            .ignoresSafeArea(.keyboard)
    }

    // MARK: - Menu Sheet

    private var menuSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    OnboardingLogo(size: 80)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                    Text("MemoryAisle")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .foregroundStyle(Theme.Text.primary)
                        .padding(.bottom, 24)

                    // Menu items
                    VStack(spacing: 4) {
                        menuRow("Progress", icon: "chart.line.uptrend.xyaxis", color: Color(hex: 0x34D399), proLocked: !isPro) {
                            openDestination(.progress)
                        }
                        menuRow("Grocery List", icon: "cart.fill", color: Color(hex: 0x4ADE80)) {
                            openDestination(.groceryList)
                        }
                        menuRow("Recipes", icon: "book.fill", color: Color(hex: 0xFBBF24)) {
                            openDestination(.recipes)
                        }
                        menuRow("Scan", icon: "barcode.viewfinder", color: Color(hex: 0x60A5FA)) {
                            openDestination(.scan)
                        }
                        menuRow("Smart Calendar", icon: "calendar", color: Color(hex: 0x38BDF8)) {
                            openDestination(.calendar)
                        }
                        menuRow("Pantry", icon: "refrigerator.fill", color: Color(hex: 0x4ADE80)) {
                            openDestination(.pantry)
                        }
                        menuRow("My Safe Space", icon: "lock.shield.fill", color: Color(hex: 0x6B6B88)) {
                            openDestination(.safeSpace)
                        }
                        menuRow("Reflection", icon: "square.and.pencil", color: Color.violet, proLocked: !isPro) {
                            openDestination(.reflection)
                        }
                        // One row, two modes. Free users upgrade via the paywall.
                        // Pro users get a benefits page that lists what they have,
                        // shows the auto-renew fine print, and embeds Apple's
                        // native Manage Subscription sheet so they can cancel,
                        // change plan, or restore from one place. Hiding the row
                        // entirely for Pro users broke 3.1.2 and left them with
                        // zero in-app path to manage or restore.
                        menuRow(
                            isPro ? "Manage Subscription" : "Subscribe",
                            icon: isPro ? "creditcard.fill" : "star.fill",
                            color: Color(hex: 0xFBBF24)
                        ) {
                            activeSheet = .destination(isPro ? .proBenefits : .subscribe)
                        }

                        Divider()
                            .background(Theme.Border.glass(for: scheme))
                            .padding(.vertical, 8)

                        menuRow("Settings", icon: "gearshape.fill", color: Theme.Text.tertiary(for: scheme)) {
                            openDestination(.settings)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .readableContentWidth()
            }
            .themeBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = nil
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.violet)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func menuRow(
        _ title: String,
        icon: String,
        color: Color,
        proLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Text.primary)

                if proLocked {
                    Text("PRO")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color(hex: 0xFBBF24))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color(hex: 0xFBBF24).opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(Color(hex: 0xFBBF24).opacity(0.3), lineWidth: 0.5)
                        )
                }

                Spacer()

                Image(systemName: proLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(proLocked ? "\(title), Pro feature" : title)
    }

    @ViewBuilder
    private func destinationView(_ dest: MenuDestination) -> some View {
        switch dest {
        case .progress: ProgressDashboardView()
        case .groceryList: GroceryListScreen()
        case .recipes: RecipesView()
        case .scan: ScanView()
        case .calendar: CalendarView()
        case .pantry: PantryView()
        case .safeSpace: SafeSpaceView()
        case .reflection: ReflectionView()
        case .subscribe: PaywallView()
        case .proBenefits: ProBenefitsView()
        case .settings: ProfileView()
        }
    }
}

enum MenuDestination: String, Identifiable, Hashable {
    case progress, groceryList, recipes, scan, calendar, pantry, safeSpace, reflection, subscribe, proBenefits, settings
    var id: String { rawValue }
}

enum MainSheet: Identifiable, Hashable {
    case mira
    case menu
    case destination(MenuDestination)

    var id: String {
        switch self {
        case .mira: "mira"
        case .menu: "menu"
        case .destination(let d): "dest-\(d.rawValue)"
        }
    }
}
