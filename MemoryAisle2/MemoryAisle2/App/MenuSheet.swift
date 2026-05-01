import SwiftUI

/// The wordmark-tap menu drawer. Owns the listing of features that are
/// not exposed on the bottom tab bar (profile, grocery, recipes, calendar,
/// pantry, safe space, subscription/manage, settings) plus the Pro-only
/// `progress` entry. SCAN, MIRA, and REFLECT live on the tab bar instead.
struct MenuSheet: View {
    @Environment(\.colorScheme) private var scheme
    let isPro: Bool
    var isOnGLP: Bool = false
    let onSelect: (MenuDestination) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OnboardingLogo(size: 80)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                Text("MemoryAisle")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .foregroundStyle(Theme.Text.primary)
                    .padding(.bottom, 24)

                VStack(spacing: 4) {
                    menuRow("My Journey", icon: "person.fill", color: Color.violet) {
                        onSelect(.profile)
                    }
                    menuRow("Progress", icon: "chart.line.uptrend.xyaxis", color: Color(hex: 0x34D399), proLocked: !isPro) {
                        onSelect(.progress)
                    }
                    menuRow("Grocery List", icon: "cart.fill", color: Color(hex: 0x4ADE80)) {
                        onSelect(.groceryList)
                    }
                    menuRow("Recipes", icon: "book.fill", color: Color(hex: 0xFBBF24)) {
                        onSelect(.recipes)
                    }
                    menuRow("Smart Calendar", icon: "calendar", color: Color(hex: 0x38BDF8)) {
                        onSelect(.calendar)
                    }
                    menuRow("Pantry", icon: "refrigerator.fill", color: Color(hex: 0x4ADE80)) {
                        onSelect(.pantry)
                    }
                    menuRow(
                        isOnGLP ? "Medications" : "Allergies & Restrictions",
                        icon: isOnGLP ? "pills.fill" : "leaf.fill",
                        color: Color(hex: 0xC084FC)
                    ) {
                        onSelect(.medications)
                    }
                    menuRow("My Safe Space", icon: "lock.shield.fill", color: Color(hex: 0x6B6B88)) {
                        onSelect(.safeSpace)
                    }
                    menuRow(
                        isPro ? "Manage Subscription" : "Subscribe",
                        icon: isPro ? "creditcard.fill" : "star.fill",
                        color: Color(hex: 0xFBBF24)
                    ) {
                        onSelect(isPro ? .proBenefits : .subscribe)
                    }

                    Divider()
                        .background(Theme.Border.glass(for: scheme))
                        .padding(.vertical, 8)

                    menuRow("Settings", icon: "gearshape.fill", color: Theme.Text.tertiary(for: scheme)) {
                        onSelect(.settings)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .readableContentWidth()
            .themeBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
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

    @ViewBuilder
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
                        .background(Capsule().fill(Color(hex: 0xFBBF24).opacity(0.12)))
                        .overlay(Capsule().stroke(Color(hex: 0xFBBF24).opacity(0.3), lineWidth: 0.5))
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
}

enum MenuDestination: String, Identifiable, Hashable {
    case profile, progress, groceryList, recipes, calendar, pantry, medications, safeSpace, reflection, scan, mira, subscribe, proBenefits, settings
    var id: String { rawValue }
}
