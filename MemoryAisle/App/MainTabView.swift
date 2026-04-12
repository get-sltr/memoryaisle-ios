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
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
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
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(Typography.caption)
            }
            .foregroundStyle(
                selectedTab == tab
                    ? Theme.Accent.primary(for: scheme)
                    : Theme.Text.tertiary(for: scheme)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .accessibilityLabel(tab.title)
    }

    // MARK: Center Scan Button (Elevated)

    private var scanButton: some View {
        Button {
            HapticManager.medium()
            withAnimation(Theme.Motion.press) {
                selectedTab = .scan
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Accent.muted(for: scheme))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.violet.opacity(0.3), lineWidth: Theme.glassBorderWidth)
                    )

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.Accent.primary(for: scheme))
            }
            .offset(y: -12)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Scan")
    }

    // MARK: Background

    private var tabBarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Theme.Surface.tabBar(for: scheme))
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.Border.tabBar(for: scheme))
                    .frame(height: Theme.glassBorderWidth)
            }
    }
}
