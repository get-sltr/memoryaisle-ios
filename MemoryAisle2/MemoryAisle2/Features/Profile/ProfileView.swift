import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    Text("Profile")
                        .font(Typography.displaySmall)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

                // Medication
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        sectionTitle("Medication")

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
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Mode
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        sectionTitle("Product Mode")

                        if let profile {
                            ForEach(ProductMode.allCases, id: \.self) { mode in
                                modeOption(mode, isSelected: profile.productMode == mode)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Targets
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        sectionTitle("Daily Targets")

                        if let profile {
                            targetRow("Protein", value: "\(profile.proteinTargetGrams)g", category: .protein)
                            targetRow("Calories", value: "\(profile.calorieTarget)", category: .calories)
                            targetRow("Water", value: String(format: "%.1fL", profile.waterTargetLiters), category: .water)
                            targetRow("Fiber", value: "\(profile.fiberTargetGrams)g", category: .fiber)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // App info
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionTitle("About")
                        infoRow("Version", value: "1.0.0")
                        infoRow("Built by", value: "SLTR Digital LLC")
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Reset onboarding (dev)
                Button {
                    resetOnboarding()
                } label: {
                    Text("Reset Onboarding")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Semantic.warning(for: scheme))
                }
                .padding(.top, Theme.Spacing.md)

                Spacer(minLength: 40)
            }
        }
        .themeBackground()
    }

    // MARK: - Components

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Typography.bodyMediumBold)
            .foregroundStyle(Theme.Accent.primary(for: scheme))
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(value)
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.primary)
        }
    }

    private func targetRow(_ label: String, value: String, category: ProgressCategory) -> some View {
        HStack {
            Circle()
                .fill(category.color(for: scheme))
                .frame(width: 8, height: 8)
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(value)
                .font(Typography.monoMedium)
                .foregroundStyle(Theme.Text.primary)
        }
    }

    private func modeOption(_ mode: ProductMode, isSelected: Bool) -> some View {
        Button {
            HapticManager.selection()
            profile?.productMode = mode
        } label: {
            HStack {
                Text(mode.rawValue)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.violet)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private func dayName(_ day: Int) -> String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return day > 0 && day < days.count ? days[day] : ""
    }

    private func resetOnboarding() {
        if let profile {
            modelContext.delete(profile)
        }
    }
}
