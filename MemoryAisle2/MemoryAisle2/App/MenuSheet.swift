import SwiftUI

/// The wordmark-tap menu drawer, laid out per the editorial spec
/// (`/Desktop/memoryaisle_menu_v3_with_health.html`): five roman-numeral
/// sections (Daily, Kitchen, Health, Mira, Account) over a gold-into-night
/// gradient. Each row is icon + title + caps subtitle + chevron, with
/// inset hairlines between rows and full-width hairlines between sections.
///
/// Mira History is intentionally omitted from the spec — Mira conversations
/// are ephemeral by product design (see `MiraTabView` privacy invariant +
/// LEGAL §2.5/2.7). Surfacing a "Past conversations" entry would contradict
/// that promise. If the spec is ever extended to include it, that decision
/// has to come with a privacy review.
struct MenuSheet: View {
    let isPro: Bool
    let onSelect: (MenuDestination) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            EditorialBackground(mode: .night)

            ScrollView {
                VStack(spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    section(label: "I · DAILY") {
                        row("Today",
                            subtitle: "MEALS · INTAKE · MIRA",
                            icon: "target",
                            action: { onSelect(.today) })
                        rowDivider
                        row("Smart Calendar",
                            subtitle: "MEAL TIMING · GLP-1",
                            icon: "calendar",
                            action: { onSelect(.calendar) })
                    }

                    sectionDivider

                    section(label: "II · KITCHEN") {
                        row("Grocery List",
                            subtitle: "WHAT TO BUY",
                            icon: "bag",
                            action: { onSelect(.groceryList) })
                        rowDivider
                        row("Pantry",
                            subtitle: "WHAT YOU HAVE",
                            icon: "refrigerator",
                            action: { onSelect(.pantry) })
                        rowDivider
                        row("Scan Receipt",
                            subtitle: "PRICE TRACKING · HISTORY",
                            icon: "doc.text.viewfinder",
                            action: { onSelect(.scanReceipt) })
                        rowDivider
                        row("Recipes",
                            subtitle: "PROTEIN-FIRST COOKING",
                            icon: "book.closed",
                            action: { onSelect(.recipes) })
                        rowDivider
                        row("Favorites",
                            subtitle: "SAVED MEALS · RECIPES",
                            icon: "heart",
                            action: { onSelect(.favorites) })
                    }

                    sectionDivider

                    section(label: "III · HEALTH") {
                        row("Medications",
                            subtitle: "GLP-1 · DOSE · SCHEDULE · REFILLS",
                            icon: "cross.case",
                            action: { onSelect(.medications) })
                        rowDivider
                        row("Food Allergies",
                            subtitle: "AVOID · RESTRICTIONS",
                            icon: "shield",
                            action: { onSelect(.foodAllergies) })
                        rowDivider
                        row("My Journey",
                            subtitle: "GOALS · PROFILE",
                            icon: "person.crop.circle",
                            action: { onSelect(.profile) })
                        rowDivider
                        row("Progress",
                            subtitle: "BODY COMPOSITION",
                            icon: "chart.line.uptrend.xyaxis",
                            proLocked: !isPro,
                            action: { onSelect(.progress) })
                        rowDivider
                        row("My Safe Space",
                            subtitle: "PRIVATE REFLECTIONS",
                            icon: "lock.shield",
                            action: { onSelect(.safeSpace) })
                    }

                    sectionDivider

                    section(label: "V · ACCOUNT") {
                        row("Email & Profile",
                            subtitle: "ACCOUNT INFO",
                            icon: "envelope",
                            action: { onSelect(.emailProfile) })
                        rowDivider
                        row("Notifications",
                            subtitle: "REMINDERS · CHECK-INS",
                            icon: "bell",
                            action: { onSelect(.notifications) })
                        rowDivider
                        row(isPro ? "Manage Subscription" : "Subscribe",
                            subtitle: "UNLOCK PRO",
                            icon: "star",
                            action: { onSelect(isPro ? .proBenefits : .subscribe) })
                        rowDivider
                        row("Settings",
                            subtitle: "PREFERENCES · DATA · PRIVACY",
                            icon: "gearshape",
                            action: { onSelect(.settings) })
                    }

                    footer
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    doneButton
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: "sparkle")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("MemoryAisle")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("LOSE FAT · KEEP MUSCLE")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 8)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Done

    private var doneButton: some View {
        Button {
            HapticManager.light()
            onClose()
        } label: {
            Text("DONE")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
    }

    // MARK: - Section

    @ViewBuilder
    private func section<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
            content()
        }
    }

    private var sectionDivider: some View {
        HairlineDivider().padding(.vertical, 8)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.Editorial.onSurface.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(
        _ title: String,
        subtitle: String,
        icon: String,
        proLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Text(subtitle)
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                }

                Spacer()

                if proLocked {
                    Text("PRO")
                        .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Theme.Editorial.onSurface.opacity(0.4), lineWidth: 0.5)
                        )
                        .padding(.trailing, 6)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(proLocked ? "\(title), Pro feature" : title)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
            Text("v 2.0.0")
                .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
        }
        .padding(.top, 32)
        .padding(.bottom, 8)
    }
}

enum MenuDestination: String, Identifiable, Hashable {
    case profile, progress, groceryList, recipes, calendar, pantry,
         safeSpace, reflection, scan, mira, subscribe, proBenefits, settings,
         today, scanReceipt, favorites, medications, foodAllergies,
         emailProfile, notifications
    var id: String { rawValue }
}
