import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var activeSheet: MainSheet?

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
                    menuRow("My Journey", icon: "person.fill", color: Color.violet) {
                        activeSheet = .destination(.profile)
                    }
                    menuRow("Recipes", icon: "book.fill", color: Color(hex: 0xFBBF24)) {
                        activeSheet = .destination(.recipes)
                    }
                    menuRow("Scan", icon: "barcode.viewfinder", color: Color(hex: 0x60A5FA)) {
                        activeSheet = .destination(.scan)
                    }
                    menuRow("Smart Calendar", icon: "calendar", color: Color(hex: 0x38BDF8)) {
                        activeSheet = .destination(.calendar)
                    }
                    menuRow("Pantry", icon: "refrigerator.fill", color: Color(hex: 0x4ADE80)) {
                        activeSheet = .destination(.pantry)
                    }
                    menuRow("My Safe Space", icon: "lock.shield.fill", color: Color(hex: 0x6B6B88)) {
                        activeSheet = .destination(.safeSpace)
                    }
                    menuRow("Progress", icon: "chart.line.uptrend.xyaxis", color: Color(hex: 0x34D399)) {
                        activeSheet = .destination(.progress)
                    }
                    menuRow("Subscribe", icon: "star.fill", color: Color(hex: 0xFBBF24)) {
                        activeSheet = .destination(.subscribe)
                    }

                    Divider()
                        .background(Theme.Border.glass(for: scheme))
                        .padding(.vertical, 8)

                    menuRow("Settings", icon: "gearshape.fill", color: Theme.Text.tertiary(for: scheme)) {
                        activeSheet = .destination(.settings)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
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

    private func menuRow(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
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

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func destinationView(_ dest: MenuDestination) -> some View {
        switch dest {
        case .profile: JourneyProfileView()
        case .recipes: RecipesView()
        case .scan: ScanView()
        case .calendar: CalendarView()
        case .pantry: PantryView()
        case .safeSpace: SafeSpaceView()
        case .progress: ProgressDashboardView()
        case .subscribe: PaywallView()
        case .settings: ProfileView()
        }
    }
}

enum MenuDestination: String, Identifiable, Hashable {
    case profile, recipes, scan, calendar, pantry, safeSpace, progress, subscribe, settings
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
