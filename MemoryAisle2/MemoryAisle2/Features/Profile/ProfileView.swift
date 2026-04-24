@preconcurrency import PhotosUI
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var profiles: [UserProfile]
    @State private var showLegal: LegalPage?
    @State private var showDeleteConfirm = false
    @State private var showPhotoCheckIn = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var avatarImage: Image?
    @State private var showMedStartPicker = false
    @State private var medStartDate: Date = UserScopedDefaults.object(forKey: "medicationStartDate") as? Date ?? Date()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeader
                    accountCard
                    statsRing
                    weeklyCheckIn
                    AppleHealthCard()
                    medicationCard
                    modeSelector
                    targetsCard
                    settingsCard
                    dangerZone

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .section(.home)
            .themeBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.violet)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $showLegal) { page in LegalView(page: page) }
        .sheet(isPresented: $showPhotoCheckIn) { PhotoCheckInView() }
        .alert("Delete everything?", isPresented: $showDeleteConfirm) {
            Button("Delete All Data", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all logs, photos, and preferences. This cannot be undone.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar with photo picker
            avatarView
                .onChange(of: selectedPhoto) { _, newValue in
                    loadAvatar(from: newValue)
                }

            // Name + badge
            if let med = profile?.medication {
                Text(med.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.violet.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.violet.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Text("Smart Nutrition")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Semantic.onTrack(for: scheme).opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.Semantic.onTrack(for: scheme).opacity(0.1))
                    .clipShape(Capsule())
            }

            if let mode = profile?.productMode {
                Text(mode.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
        }
        .padding(.top, 8)
        .onAppear {
            if let data = UserScopedDefaults.data(forKey: "ma_avatar"),
               let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
            }
        }
    }

    @State private var showPhotoPicker = false

    private var avatarView: some View {
        Button { showPhotoPicker = true } label: {
            ZStack(alignment: .bottomTrailing) {
                if let avatarImage {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.violet.opacity(0.4))
                        .frame(width: 90, height: 90)
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.violet)
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change profile photo")
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
    }

    // MARK: - Account

    /// Shows the currently signed-in email and sign-in method so users
    /// can confirm which account they are in without having to sign out
    /// and back in. Critical for a health app where the account holds
    /// medication and GI tolerance data.
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNT")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)

            accountRow(
                label: "Email",
                value: accountEmail,
                icon: "envelope.fill"
            )
            accountRow(
                label: "Sign-in method",
                value: signInMethodLabel,
                icon: isSignedInWithApple ? "applelogo" : "key.fill"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func accountRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.violet.opacity(0.5))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var accountEmail: String {
        CognitoAuthManager.currentEmail() ?? "Hidden by Apple"
    }

    private var isSignedInWithApple: Bool {
        CognitoAuthManager.isSignedInWithApple()
    }

    private var signInMethodLabel: String {
        isSignedInWithApple ? "Apple" : "Email"
    }

    // MARK: - Stats Ring

    private var statsRing: some View {
        HStack(spacing: 0) {
            statItem(
                "\(profile?.proteinTargetGrams ?? 0)g",
                label: "Protein",
                color: Color.violet
            )
            divider
            statItem(
                "\(profile?.calorieTarget ?? 0)",
                label: "Calories",
                color: Theme.Text.secondary(for: scheme)
            )
            divider
            statItem(
                String(format: "%.1fL", profile?.waterTargetLiters ?? 2.5),
                label: "Water",
                color: Theme.Semantic.water(for: scheme)
            )
            divider
            statItem(
                "\(profile?.fiberTargetGrams ?? 25)g",
                label: "Fiber",
                color: Theme.Semantic.fiber(for: scheme)
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func statItem(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Border.glass(for: scheme))
            .frame(width: 0.5, height: 30)
    }

    // MARK: - Weekly Check-In

    private var weeklyCheckIn: some View {
        Button {
            showPhotoCheckIn = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.violet.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.violet)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly Check-In")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Text.primary)
                    Text("Log weight and take a progress photo")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Weekly check-in")
    }

    // MARK: - Medication Card

    private var medicationCard: some View {
        Group {
            if profile?.medication != nil {
                section("Medication") {
                    if let med = profile?.medication {
                        infoRow("Medication", value: med.rawValue)
                    }
                    if let modality = profile?.medicationModality {
                        infoRow("Type", value: modality.displayName)
                    }
                    if let dose = profile?.doseAmount, !dose.isEmpty {
                        infoRow("Dose", value: dose)
                    }
                    if let day = profile?.injectionDay {
                        infoRow("Injection Day", value: dayName(day))
                    }

                    Button {
                        withAnimation { showMedStartPicker.toggle() }
                    } label: {
                        HStack {
                            Text("Started")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                            Spacer()
                            Text(medStartDate, style: .date)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.Text.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                .rotationEffect(.degrees(showMedStartPicker ? 180 : 0))
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Medication start date")

                    if showMedStartPicker {
                        DatePicker(
                            "",
                            selection: $medStartDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: medStartDate) { _, newDate in
                            UserScopedDefaults.set(newDate, forKey: "medicationStartDate")
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        section("Mode") {
            if let profile {
                ForEach(ProductMode.allCases, id: \.self) { mode in
                    let isSelected = profile.productMode == mode
                    Button {
                        HapticManager.selection()
                        profile.productMode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.violet)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Targets

    /// User-editable daily targets. Each row is a Stepper bound to the
    /// corresponding property on `UserProfile`; changes persist through
    /// SwiftData automatically with no explicit save call required.
    ///
    /// Ranges are deliberately generous so users on very different
    /// protocols (cutting vs. bulking, low-cal vs. high-cal) aren't
    /// blocked from setting what they need. Step sizes are chosen for
    /// ergonomic tapping — 5 for protein/fiber, 50 for calories, 0.1
    /// for water.
    private var targetsCard: some View {
        section("Daily Targets") {
            if let profile {
                editableIntTarget(
                    label: "Protein",
                    color: Color.violet,
                    value: Binding(
                        get: { profile.proteinTargetGrams },
                        set: { profile.proteinTargetGrams = $0 }
                    ),
                    suffix: "g",
                    range: 40...300,
                    step: 5
                )
                editableIntTarget(
                    label: "Calories",
                    color: Theme.Text.secondary(for: scheme),
                    value: Binding(
                        get: { profile.calorieTarget },
                        set: { profile.calorieTarget = $0 }
                    ),
                    suffix: "",
                    range: 800...4000,
                    step: 50
                )
                editableDoubleTarget(
                    label: "Water",
                    color: Theme.Semantic.water(for: scheme),
                    value: Binding(
                        get: { profile.waterTargetLiters },
                        set: { profile.waterTargetLiters = $0 }
                    ),
                    format: { String(format: "%.1fL", $0) },
                    range: 1.0...5.0,
                    step: 0.1
                )
                editableIntTarget(
                    label: "Fiber",
                    color: Theme.Semantic.fiber(for: scheme),
                    value: Binding(
                        get: { profile.fiberTargetGrams },
                        set: { profile.fiberTargetGrams = $0 }
                    ),
                    suffix: "g",
                    range: 10...60,
                    step: 1
                )
            }
        }
    }

    private func editableIntTarget(
        label: String,
        color: Color,
        value: Binding<Int>,
        suffix: String,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text("\(value.wrappedValue)\(suffix)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Text.primary)
                .frame(minWidth: 56, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { _, _ in
                    HapticManager.selection()
                }
        }
        .padding(.vertical, 2)
    }

    private func editableDoubleTarget(
        label: String,
        color: Color,
        value: Binding<Double>,
        format: @escaping (Double) -> String,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(format(value.wrappedValue))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Text.primary)
                .frame(minWidth: 56, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { _, _ in
                    HapticManager.selection()
                }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingsRow("Terms of Service") { showLegal = .terms }
            settingsRow("Privacy Policy") { showLegal = .privacy }
            settingsRow("Medical Disclaimer") { showLegal = .medical }
            settingsRow("Security") { showLegal = .dataPolicy }

            Divider().background(Theme.Border.glass(for: scheme)).padding(.vertical, 8)

            settingsRow("Sync to Cloud", icon: "arrow.triangle.2.circlepath") {
                Task {
                    let sync = CloudSyncManager()
                    let userId = UserDefaults.standard.string(forKey: "ma_email") ?? ""
                    await sync.pushAll(userId: userId, modelContext: modelContext)
                    HapticManager.success()
                }
            }

            settingsRow("Sign Out", icon: "rectangle.portrait.and.arrow.right") {
                HapticManager.warning()
                Task {
                    await CognitoAuthManager.signOutEverywhere(
                        modelContext: modelContext,
                        subscription: subscriptionManager
                    )
                    appState.authStatus = .signedOut
                    dismiss()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func settingsRow(_ title: String, icon: String = "chevron.right", action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.warning()
                resetOnboarding()
            } label: {
                Text("Reset Onboarding")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Semantic.warning(for: scheme).opacity(0.5))
            }
            .accessibilityLabel("Reset onboarding")

            Button {
                showDeleteConfirm = true
            } label: {
                Text("Delete Account & All Data")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Semantic.warning(for: scheme).opacity(0.7))
            }
            .accessibilityLabel("Delete account and all data")
        }
        .padding(.top, 8)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)
            VStack(spacing: 6) { content() }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
        }
        .padding(.vertical, 2)
    }

    private func targetRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Text.primary)
        }
        .padding(.vertical, 2)
    }

    private func dayName(_ day: Int) -> String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return day > 0 && day < days.count ? days[day] : ""
    }

    private func loadAvatar(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                if let data, let uiImage = UIImage(data: data) {
                    avatarImage = Image(uiImage: uiImage)
                    UserScopedDefaults.set(data, forKey: "ma_avatar")
                }
            }
        }
    }

    private func resetOnboarding() {
        if let profile { modelContext.delete(profile) }
        appState.hasCompletedOnboarding = false
    }

    private func deleteAllData() {
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

            // Centralized purge: wipes every user-owned SwiftData type,
            // the reviewer Pro override, keychain session, and resets
            // the subscription tier in one place.
            await CognitoAuthManager.signOutEverywhere(
                modelContext: modelContext,
                subscription: subscriptionManager
            )

            appState.hasCompletedOnboarding = false
            appState.authStatus = .signedOut
            HapticManager.heavy()
            dismiss()
        }
    }
}
