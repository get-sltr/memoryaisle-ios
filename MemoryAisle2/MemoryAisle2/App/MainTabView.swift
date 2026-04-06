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
        ZStack {
            // Background
            tabBarBackground
                .frame(height: 56)

            // Tab items
            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.meals)

                // Spacer for center button
                Color.clear
                    .frame(width: 72)

                tabButton(.mira)
                tabButton(.progress)
            }
            .padding(.horizontal, Theme.Spacing.xs)

            // Center scan button (floating above)
            scanButton
                .offset(y: -20)
        }
        .frame(height: 56)
        .padding(.bottom, safeAreaBottom)
        .background(tabBarBackground)
    }

    private var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    // MARK: Regular Tab Button

    private func tabButton(_ tab: AppState.Tab) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(
                selectedTab == tab
                    ? Theme.Accent.primary(for: scheme)
                    : Theme.Text.tertiary(for: scheme)
            )
            .frame(maxWidth: .infinity)
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
                    .fill(
                        LinearGradient(
                            colors: [.violetDeep, .violetMid],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: Color.violetDeep.opacity(0.35),
                        radius: 12,
                        y: 4
                    )

                Image(systemName: "viewfinder")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
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
