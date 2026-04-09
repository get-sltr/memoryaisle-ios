import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:
                    NavigationStack(path: $state.homePath) {
                        HomeView()
                    }
                case .recipes:
                    NavigationStack(path: $state.recipesPath) {
                        RecipesView()
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

            CustomTabBar(selectedTab: $state.selectedTab)
        }
        .overlay {
            if appState.selectedTab != .mira {
                MiraFloatingButton {
                    withAnimation(Theme.Motion.spring) {
                        appState.selectedTab = .mira
                    }
                }
                .allowsHitTesting(true)
            }
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
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
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
        )
    }

    private func tabItem(_ tab: AppState.Tab) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: selectedTab == tab ? .medium : .light))

                Text(tab.title)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.4)
            }
            .foregroundStyle(
                selectedTab == tab
                    ? Color.violet
                    : Theme.Text.tertiary(for: scheme)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .accessibilityLabel(tab.title)
    }
}
