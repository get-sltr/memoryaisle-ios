import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @State private var showLegal: LegalPage?
    @State private var showDeleteConfirm = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close
            HStack {
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(Theme.Surface.strong(for: scheme))
                        )
                }

                Spacer()

                Text("Profile")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Logo + user info
                    VStack(spacing: 10) {
                        OnboardingLogo()

                        if let med = profile?.medication {
                            Text(med.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(hex: 0xA78BFA).opacity(0.08))
                                .clipShape(Capsule())
                        } else {
                            Text("Smart Nutrition")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: 0x34D399).opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(hex: 0x34D399).opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                    // Medication section
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
                    }

                    // Mode section
                    section("Product Mode") {
                        if let profile {
                            ForEach(ProductMode.allCases, id: \.self) { mode in
                                let isSelected = profile.productMode == mode

                                Button {
                                    HapticManager.selection()
                                    profile.productMode = mode
                                } label: {
                                    Text(mode.rawValue)
                                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                                        .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected ? Color.violet.opacity(0.15) : .clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(isSelected ? Color.violet.opacity(0.3) : .clear, lineWidth: 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Targets section
                    section("Daily Targets") {
                        if let profile {
                            targetRow("Protein", value: "\(profile.proteinTargetGrams)g", color: Color.violet)
                            targetRow("Calories", value: "\(profile.calorieTarget)", color: Theme.Text.secondary(for: scheme))
                            targetRow("Water", value: String(format: "%.1fL", profile.waterTargetLiters), color: Color(hex: 0x38BDF8))
                            targetRow("Fiber", value: "\(profile.fiberTargetGrams)g", color: Color(hex: 0xFBBF24))
                        }
                    }

                    // About + Legal
                    section("About") {
                        infoRow("Version", value: "1.0.0")
                        infoRow("Built by", value: "SLTR Digital LLC")
                    }

                    section("Legal") {
                        legalLink(.terms)
                        legalLink(.privacy)
                        legalLink(.medical)
                        legalLink(.community)
                        legalLink(.dataPolicy)
                    }

                    // Sync
                    section("Cloud Sync") {
                        Button {
                            Task {
                                let sync = CloudSyncManager()
                                let userId = UserDefaults.standard.string(forKey: "ma_email") ?? ""
                                await sync.pushAll(userId: userId, modelContext: modelContext)
                                HapticManager.success()
                            }
                        } label: {
                            HStack {
                                Text("Sync now")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.violet.opacity(0.5))
                            }
                        }
                    }

                    // Sign out
                    Button {
                        HapticManager.warning()
                        CognitoAuthManager().signOut()
                        appState.authStatus = .signedOut
                        dismiss()
                    } label: {
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                    .padding(.top, 12)

                    // Reset
                    Button {
                        HapticManager.warning()
                        resetOnboarding()
                    } label: {
                        Text("Reset Onboarding")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: 0xF87171).opacity(0.4))
                    }
                    .padding(.top, 4)

                    // Delete account
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Account & All Data")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: 0xF87171).opacity(0.6))
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .themeBackground()
        .sheet(item: $showLegal) { page in
            LegalView(page: page)
        }
        .alert("Delete everything?", isPresented: $showDeleteConfirm) {
            Button("Delete All Data", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all logs, photos, and preferences. This cannot be undone.")
        }
    }

    private func legalLink(_ page: LegalPage) -> some View {
        Button {
            showLegal = page
        } label: {
            HStack {
                Text(page.rawValue)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)

            VStack(spacing: 6) {
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
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

    private func resetOnboarding() {
        if let profile {
            modelContext.delete(profile)
        }
        appState.hasCompletedOnboarding = false
    }

    private func deleteAllData() {
        Task {
            // 1. Delete cloud data first
            let userId = UserDefaults.standard.string(forKey: "ma_email") ?? ""
            let sync = CloudSyncManager()
            _ = await sync.deleteAllCloudData(userId: userId)

            // 2. Delete all SwiftData records
            try? modelContext.delete(model: UserProfile.self)
            try? modelContext.delete(model: NutritionLog.self)
            try? modelContext.delete(model: SymptomLog.self)
            try? modelContext.delete(model: PantryItem.self)
            try? modelContext.delete(model: GIToleranceRecord.self)

            // 3. Delete local progress photos
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let photosDir = documentsPath.appendingPathComponent("ProgressPhotos")
            try? fileManager.removeItem(at: photosDir)

            // 4. Clear ALL UserDefaults
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }

            // 5. Sign out
            CognitoAuthManager().signOut()

            // 6. Reset app state
            appState.hasCompletedOnboarding = false
            appState.authStatus = .signedOut

            HapticManager.heavy()
            dismiss()
        }
    }
}
