import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]

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
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(.white.opacity(0.05))
                        )
                }

                Spacer()

                Text("Profile")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Mira + greeting
                    VStack(spacing: 12) {
                        MiraWaveform(state: .idle, size: .hero)
                            .frame(height: 40)

                        if let med = profile?.medication {
                            Text(med.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.violet.opacity(0.7))
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 8)

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
                                        .foregroundStyle(.white.opacity(isSelected ? 1 : 0.5))
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
                            targetRow("Calories", value: "\(profile.calorieTarget)", color: .white.opacity(0.4))
                            targetRow("Water", value: String(format: "%.1fL", profile.waterTargetLiters), color: Color(hex: 0x38BDF8))
                            targetRow("Fiber", value: "\(profile.fiberTargetGrams)g", color: Color(hex: 0xFBBF24))
                        }
                    }

                    // About
                    section("About") {
                        infoRow("Version", value: "1.0.0")
                        infoRow("Built by", value: "SLTR Digital LLC")
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
                            .foregroundStyle(.white.opacity(0.5))
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

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .themeBackground()
    }

    // MARK: - Components

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
                .tracking(1.2)

            VStack(spacing: 6) {
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
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
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
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
}
