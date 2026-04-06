import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch appState.selectedTab {
                case .home:
                    NavigationStack(path: $state.homePath) {
                        HomeView()
                    }
                case .meals:
                    NavigationStack(path: $state.mealsPath) {
                        MealsView()
                    }
                case .scan:
                    ScanView()
                case .mira:
                    NavigationStack(path: $state.miraPath) {
                        MiraChatView()
                    }
                case .progress:
                    NavigationStack(path: $state.progressPath) {
                        ProgressDashboardView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            CustomTabBar(selectedTab: $state.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppState.Tab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.meals)
            scanButton
            tabButton(.mira)
            tabButton(.progress)
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .padding(.horizontal, 4)
        .background(tabBarBackground)
    }

    // MARK: Regular Tab Button

    private func tabButton(_ tab: AppState.Tab) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .light))

                Text(tab.title)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.3)
            }
            .foregroundStyle(
                selectedTab == tab
                    ? Theme.Accent.primary(for: scheme)
                    : Theme.Text.tertiary(for: scheme)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .accessibilityLabel(tab.title)
    }

    // MARK: Center Scan Button

    private var scanButton: some View {
        Button {
            HapticManager.medium()
            withAnimation(Theme.Motion.press) {
                selectedTab = .scan
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            selectedTab == .scan
                                ? Color.violetDeep
                                : Color.violetDeep.opacity(0.6)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                }

                Text("Scan")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(
                        selectedTab == .scan
                            ? Theme.Accent.primary(for: scheme)
                            : Theme.Text.tertiary(for: scheme)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel("Scan")
    }

    // MARK: Background

    private var tabBarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.Border.glass(for: scheme))
                    .frame(height: Theme.glassBorderWidth)
            }
    }
}
