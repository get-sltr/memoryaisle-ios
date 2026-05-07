import SwiftData
import SwiftUI

/// Editorial Settings sheet — the destination of the menu's "Settings" row.
/// Layout matches `/Desktop/memoryaisle_settings_subscreen.html`: four
/// roman-numeral sections (Appearance, Privacy & Consent, Your Data,
/// Danger Zone) over the gold-into-night gradient.
///
/// User-profile content (medication, targets, body stats, weekly check-in)
/// stays on the legacy `ProfileView` tree under `.profile` — Settings is
/// now narrowly scoped to preferences, privacy, and account-level actions.
struct EditorialSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var profiles: [UserProfile]

    @State private var showLegal: LegalPage?
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteDataConfirm = false
    @State private var showConsentAlert = false
    @State private var showExportSheet = false
    @State private var showResetOnboardingConfirm = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            ScrollView {
                VStack(spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    appearanceSection
                    sectionDivider
                    unitsSection
                    sectionDivider
                    numbersSection
                    sectionDivider
                    privacySection
                    sectionDivider
                    yourDataSection
                    sectionDivider
                    dangerZoneSection

                    footer
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    backButton
                    Spacer()
                    doneButton
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .sheet(item: $showLegal) { page in LegalView(page: page) }
        .alert("Delete account?", isPresented: $showDeleteAccountConfirm) {
            Button("Delete account", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your account, all data, and signs you out. Subscriptions billed through Apple must be cancelled separately in Settings > Apple ID. We process within 30 days.")
        }
        .alert("Delete my data?", isPresented: $showDeleteDataConfirm) {
            Button("Delete my data", role: .destructive) {
                Task { await deleteMyData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This wipes your meals, scans, body composition history, and progress photos from this device. Your account stays active. You will be sent back through onboarding.")
        }
        .alert("Consent settings", isPresented: $showConsentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Coming soon. Analytics and AI-training consent toggles will land in a follow-up build.")
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDataSheet()
        }
        .alert("Reset onboarding?", isPresented: $showResetOnboardingConfirm) {
            Button("Reset", role: .destructive) { resetOnboarding() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Re-runs the onboarding flow. Your meals, scans, weight history, and Mira context all stay. You'll set up your goals and medication info again.")
        }
    }

    // MARK: - Reset onboarding

    private func resetOnboarding() {
        HapticManager.heavy()
        appState.hasCompletedOnboarding = false
        if let profile {
            profile.hasCompletedOnboarding = false
        }
        dismiss()
    }

    private func deleteMyData() async {
        HapticManager.warning()
        await LocalDataPurgeService.purgeAll(modelContext: modelContext)

        appState.hasCompletedOnboarding = false
        if let profile {
            profile.hasCompletedOnboarding = false
        }
        dismiss()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: "sparkle")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("Settings")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("PREFERENCES · DATA · PRIVACY")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 8)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Top buttons

    private var backButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Text("‹ BACK")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var doneButton: some View {
        Button {
            HapticManager.light()
            dismiss()
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

    // MARK: - Sections

    private var appearanceSection: some View {
        section(label: "I · APPEARANCE") {
            modePicker
        }
    }

    private var unitsSection: some View {
        section(label: "II · UNITS") {
            unitsPicker
        }
    }

    private var numbersSection: some View {
        section(label: "III · NUMBERS") {
            numbersPicker
        }
    }

    private var privacySection: some View {
        section(label: "IV · PRIVACY & CONSENT") {
            row("Consent",
                subtitle: "ANALYTICS · AI TRAINING",
                icon: "lock") {
                showConsentAlert = true
            }
            rowDivider
            row("Privacy Policy",
                subtitle: "READ FULL DOCUMENT",
                icon: "doc.text") {
                showLegal = .privacy
            }
            rowDivider
            row("Terms of Service",
                subtitle: "READ FULL DOCUMENT",
                icon: "doc.plaintext") {
                showLegal = .terms
            }
        }
    }

    private var yourDataSection: some View {
        section(label: "V · YOUR DATA") {
            row("Export Data",
                subtitle: "DOWNLOAD A COPY",
                icon: "arrow.down.circle") {
                showExportSheet = true
            }
            rowDivider
            row("Delete My Data",
                subtitle: "WIPE MEALS, SCANS, HISTORY",
                icon: "trash",
                tint: warningTint) {
                showDeleteDataConfirm = true
            }
            finePrint(text: "Delete My Data wipes on-device meals, scans, and progress history. It does not delete your account. If you have cloud sync enabled, you may need to delete cloud data separately.",
                      tint: warningTint)
        }
    }

    private var dangerZoneSection: some View {
        section(label: "VI · DANGER ZONE") {
            row("Reset Onboarding",
                subtitle: "RE-RUN THE FLOW · KEEPS DATA",
                icon: "arrow.counterclockwise",
                tint: dangerTint.opacity(0.75)) {
                showResetOnboardingConfirm = true
            }
            row("Delete Account",
                subtitle: "PERMANENT · CANNOT UNDO",
                icon: "exclamationmark.triangle",
                tint: dangerTint) {
                showDeleteAccountConfirm = true
            }
            finePrint(text: "This deletes your account, all data, and active subscriptions. Mira forgets you. Your email is released so you can sign up again later. Subscriptions billed through Apple must be cancelled separately in Settings > Apple ID. We process within 30 days; legally required records are retained per the Privacy Policy.",
                      tint: dangerTint)
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "moon")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 18)
                Text("MODE")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                modeChip(.day,   icon: "sun.max")
                modeChip(.night, icon: "moon")
                modeChip(.auto,  icon: "circle.lefthalf.filled")
            }
            .padding(.leading, 38)

            Text("AUTO FOLLOWS TIME OF DAY")
                .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                .padding(.leading, 38)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func modeChip(_ choice: AppearanceChoice, icon: String) -> some View {
        let selected = currentAppearanceChoice == choice
        Button {
            HapticManager.selection()
            withAnimation(.easeInOut(duration: 0.4)) {
                appState.appearanceMode = choice.mode
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                Text(choice.shortLabel)
                    .font(Theme.Editorial.Typography.caps(9, weight: selected ? .semibold : .medium))
                    .tracking(1.8)
            }
            .foregroundStyle(Theme.Editorial.onSurface.opacity(selected ? 1.0 : 0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Editorial.onSurface.opacity(selected ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Theme.Editorial.onSurface.opacity(selected ? 0.7 : 0.15),
                        lineWidth: selected ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.label)\(selected ? ", selected" : "")")
    }

    // MARK: - Units picker

    private var unitsPicker: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "ruler")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 18)
                Text("WEIGHT · HEIGHT")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                unitsChip(.imperial)
                unitsChip(.metric)
            }
            .padding(.leading, 38)

            Text("DEFAULT FOLLOWS YOUR REGION")
                .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                .padding(.leading, 38)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func unitsChip(_ choice: UnitSystem) -> some View {
        let selected = appState.unitSystem == choice
        Button {
            HapticManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.unitSystem = choice
            }
        } label: {
            VStack(spacing: 4) {
                Text(choice.label)
                    .font(Theme.Editorial.Typography.caps(10, weight: selected ? .semibold : .medium))
                    .tracking(1.8)
                Text(choice.sublabel)
                    .font(Theme.Editorial.Typography.caps(8, weight: .regular))
                    .tracking(1.4)
                    .opacity(0.65)
            }
            .foregroundStyle(Theme.Editorial.onSurface.opacity(selected ? 1.0 : 0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Editorial.onSurface.opacity(selected ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Theme.Editorial.onSurface.opacity(selected ? 0.7 : 0.15),
                        lineWidth: selected ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.label) units\(selected ? ", selected" : "")")
    }

    // MARK: - Numbers picker

    private var numbersPicker: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "number")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 18)
                Text("DATES · MARKERS")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                numbersChip(.roman)
                numbersChip(.arabic)
            }
            .padding(.leading, 38)

            Text("MASTHEAD AND DAY MARKERS")
                .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                .padding(.leading, 38)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func numbersChip(_ choice: NumberStyle) -> some View {
        let selected = appState.numberStyle == choice
        Button {
            HapticManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.numberStyle = choice
            }
        } label: {
            VStack(spacing: 4) {
                Text(choice.label)
                    .font(Theme.Editorial.Typography.caps(10, weight: selected ? .semibold : .medium))
                    .tracking(1.8)
                Text(choice.sublabel)
                    .font(Theme.Editorial.Typography.caps(8, weight: .regular))
                    .tracking(1.4)
                    .opacity(0.65)
            }
            .foregroundStyle(Theme.Editorial.onSurface.opacity(selected ? 1.0 : 0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Editorial.onSurface.opacity(selected ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Theme.Editorial.onSurface.opacity(selected ? 0.7 : 0.15),
                        lineWidth: selected ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.label) numbers\(selected ? ", selected" : "")")
    }

    private var currentAppearanceChoice: AppearanceChoice {
        switch appState.appearanceMode {
        case nil:      return .auto
        case .day?:    return .day
        case .night?:  return .night
        }
    }

    // MARK: - Section + row primitives

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

    @ViewBuilder
    private func row(
        _ title: String,
        subtitle: String,
        icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let foreground = tint ?? Theme.Editorial.onSurface
        let mutedForeground = (tint ?? Theme.Editorial.onSurface).opacity(0.65)

        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(foreground)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(foreground)
                    Text(subtitle)
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(mutedForeground)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(foreground.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func finePrint(text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FINE PRINT")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                .lineSpacing(4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.black.opacity(0.18)
                .overlay(
                    Rectangle()
                        .fill(tint.opacity(0.5))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity),
                    alignment: .leading
                )
        )
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 12)
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

    // MARK: - Tints

    private var warningTint: Color {
        Color(red: 0.961, green: 0.851, blue: 0.478)  // soft gold from spec
    }

    private var dangerTint: Color {
        Color(red: 0.910, green: 0.659, blue: 0.486)  // peach from spec
    }

    // MARK: - Actions

    /// Wipes all user data and signs out. Mirrors the legacy
    /// `ProfileView.deleteAllData` flow — same purge surface, just behind
    /// the new editorial UI.
    private func deleteAccount() {
        Task {
            let userId = UserDefaults.standard.string(forKey: "ma_email") ?? ""
            let sync = CloudSyncManager()
            _ = await sync.deleteAllCloudData(userId: userId)

            let fileManager = FileManager.default
            if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? fileManager.removeItem(at: documentsPath.appendingPathComponent("ProgressPhotos"))
            }

            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }

            await CognitoAuthManager.signOutEverywhere(
                modelContext: modelContext,
                subscription: subscriptionManager
            )

            appState.hasCompletedOnboarding = false
            appState.cognitoUserId = nil
            appState.authStatus = .signedOut
            HapticManager.heavy()
            dismiss()
        }
    }
}

// MARK: - Short label for AppearanceChoice

private extension AppearanceChoice {
    var shortLabel: String {
        switch self {
        case .auto:  "AUTO"
        case .day:   "DAY"
        case .night: "NIGHT"
        }
    }
}
