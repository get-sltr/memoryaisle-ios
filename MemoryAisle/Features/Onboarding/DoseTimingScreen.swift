import SwiftUI

struct DoseTimingScreen: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var modality: MedicationModality {
        guard let med = profile.medication else { return .injectable }
        switch med {
        case .wegovyPill, .rybelsus:
            return .oralWithFasting
        case .foundayo:
            return .oralNoFasting
        default:
            return .injectable
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Dose and timing")
                        .font(Typography.displaySmall)
                        .foregroundStyle(.white)
                        .padding(.top, Theme.Spacing.xl)

                    // Dose input
                    GlassCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Current dose")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.white.opacity(0.5))

                            TextField("e.g. 0.5mg", text: Binding(
                                get: { profile.doseAmount ?? "" },
                                set: { profile.doseAmount = $0 }
                            ))
                            .font(Typography.bodyLarge)
                            .foregroundStyle(.white)
                            .keyboardType(.decimalPad)
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    // Modality-specific
                    if modality == .injectable {
                        injectableTiming
                    } else if modality == .oralWithFasting {
                        oralFastingTiming
                    } else {
                        noFastingNote
                    }

                    // Mira context
                    GlassCard {
                        HStack(spacing: Theme.Spacing.sm) {
                            MiraWaveform(state: .idle, size: .compact)
                            Text("I'll adjust your meals based on where you are in your cycle.")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }

            VioletButton("Continue") {
                profile.modality = modality
                onContinue()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    // MARK: - Injectable

    private var injectableTiming: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Injection day")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(zip(1...7, ["S","M","T","W","T","F","S"])), id: \.0) { day, label in
                        Button {
                            HapticManager.selection()
                            profile.injectionDay = day
                        } label: {
                            Text(label)
                                .font(Typography.bodyMediumBold)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    profile.injectionDay == day
                                        ? Color.violetDeep
                                        : Theme.Surface.glass(for: scheme)
                                )
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Oral with fasting

    private var oralFastingTiming: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("What time do you take your pill?")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.white.opacity(0.5))

                DatePicker(
                    "",
                    selection: Binding(
                        get: { profile.pillTime ?? Calendar.current.date(from: DateComponents(hour: 7))! },
                        set: { profile.pillTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)

                Text("Mira will plan breakfast around your 30-minute window.")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - No fasting

    private var noFastingNote: some View {
        GlassCard {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: 0x34D399))
                    .font(.system(size: 22))

                Text("No timing restrictions. I'll plan meals for maximum absorption and comfort.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}
