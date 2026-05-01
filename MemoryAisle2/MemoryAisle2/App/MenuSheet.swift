import SwiftData
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

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var accountExpanded = false
    @State private var activeAccountSheet: AccountSheet?
    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

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
                        row("Medication & Allergies",
                            subtitle: "GLP-1 · DOSE · SCHEDULE · REFILLS",
                            icon: "cross.case",
                            action: { onSelect(.medications) })
                        rowDivider
                        row("My Journey",
                            subtitle: "PHOTOS · METRICS · TOOLS",
                            icon: "person.crop.circle",
                            proLocked: !isPro,
                            action: { onSelect(.profile) })
                        rowDivider
                        row("My Safe Space",
                            subtitle: "PRIVATE REFLECTIONS",
                            icon: "lock.shield",
                            action: { onSelect(.safeSpace) })
                    }

                    sectionDivider

                    section(label: "V · ACCOUNT") {
                        accountRow
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
        .sheet(item: $activeAccountSheet) { sheet in
            switch sheet {
            case .changeEmail:
                ChangeEmailSheet(onDone: { activeAccountSheet = nil })
            case .changePassword:
                ChangePasswordSheet(onDone: { activeAccountSheet = nil })
            }
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await CognitoAuthManager.signOutEverywhere(
                        modelContext: modelContext,
                        subscription: subscriptionManager
                    )
                    appState.cognitoUserId = nil
                    appState.authStatus = .signedOut
                    onClose()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This signs you out on this device. Your meals, logs, and journey stay on-device and will be there when you sign back in.")
        }
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

    // MARK: - Account row (expandable)

    private var accountRow: some View {
        VStack(spacing: 0) {
            Button {
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    accountExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "envelope")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email & Profile")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.Editorial.onSurface)
                        Text(accountSubtitle)
                            .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                            .tracking(1.6)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                        .rotationEffect(.degrees(accountExpanded ? 90 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Email and profile")

            if accountExpanded {
                VStack(spacing: 0) {
                    subRow(
                        title: "Email",
                        value: currentEmailLabel,
                        icon: "at",
                        actionTitle: "Change",
                        action: { activeAccountSheet = .changeEmail }
                    )
                    rowDivider
                    subRow(
                        title: "Password",
                        value: "••••••••",
                        icon: "key",
                        actionTitle: "Change",
                        action: { activeAccountSheet = .changePassword }
                    )
                    rowDivider
                    signOutRow
                }
                .padding(.leading, 34)
                .padding(.bottom, 10)
            }
        }
    }

    private var signOutRow: some View {
        Button {
            HapticManager.warning()
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                    .frame(width: 18)

                Text("Sign Out")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))

                Spacer()

                Text("SIGN OUT")
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(Color(red: 0.910, green: 0.659, blue: 0.486))
            }
            .padding(.vertical, 10)
            .padding(.trailing, 4)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign out")
    }

    private var currentEmailLabel: String {
        UserDefaults.standard.string(forKey: "ma_email") ?? "—"
    }

    private var accountSubtitle: String {
        let email = UserDefaults.standard.string(forKey: "ma_email")
        if let email, !email.isEmpty {
            return email.uppercased()
        }
        return "ACCOUNT INFO"
    }

    private func subRow(
        title: String,
        value: String,
        icon: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))

            Spacer()

            Text(value)
                .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                .lineLimit(1)

            Button {
                HapticManager.light()
                action()
            } label: {
                Text(actionTitle.uppercased())
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Editorial.onSurface.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(actionTitle) \(title)")
        }
        .padding(.vertical, 10)
        .padding(.trailing, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
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
         today, scanReceipt, favorites, medications,
         notifications
    var id: String { rawValue }
}

private enum AccountSheet: String, Identifiable {
    case changeEmail
    case changePassword

    var id: String { rawValue }
}
