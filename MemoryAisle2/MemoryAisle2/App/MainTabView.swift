import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var showMira = false
    @State private var showMenu = false
    @State private var menuDestination: MenuDestination?

    var body: some View {
        ZStack {
            // Main content is always the grocery list (HomeView)
            HomeView(showMenu: $showMenu)

            // Floating Mira button - left edge, 1/3 down
            VStack {
                Spacer()
                    .frame(maxHeight: .infinity)
                MiraFloatingButton {
                    showMira = true
                }
                .padding(.leading, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Spacer()
            }
        }
        .sheet(isPresented: $showMira) {
            MiraChatView()
        }
        .sheet(item: $menuDestination) { dest in
            destinationView(dest)
        }
        .sheet(isPresented: $showMenu) {
            menuSheet
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
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .profile
                        }
                    }
                    menuRow("Recipes", icon: "book.fill", color: Color(hex: 0xFBBF24)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .recipes
                        }
                    }
                    menuRow("Scan", icon: "barcode.viewfinder", color: Color(hex: 0x60A5FA)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .scan
                        }
                    }
                    menuRow("Smart Calendar", icon: "calendar", color: Color(hex: 0x38BDF8)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .calendar
                        }
                    }
                    menuRow("Pantry", icon: "refrigerator.fill", color: Color(hex: 0x4ADE80)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .pantry
                        }
                    }
                    menuRow("My Safe Space", icon: "lock.shield.fill", color: Color(hex: 0x6B6B88)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .safeSpace
                        }
                    }
                    menuRow("Progress", icon: "chart.line.uptrend.xyaxis", color: Color(hex: 0x34D399)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .progress
                        }
                    }
                    menuRow("Subscribe", icon: "star.fill", color: Color(hex: 0xFBBF24)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .subscribe
                        }
                    }

                    Divider()
                        .background(Theme.Border.glass(for: scheme))
                        .padding(.vertical, 8)

                    menuRow("Settings", icon: "gearshape.fill", color: Theme.Text.tertiary(for: scheme)) {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            menuDestination = .settings
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .themeBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showMenu = false
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.violet)
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

enum MenuDestination: String, Identifiable {
    case profile, recipes, scan, calendar, pantry, safeSpace, progress, subscribe, settings
    var id: String { rawValue }
}
