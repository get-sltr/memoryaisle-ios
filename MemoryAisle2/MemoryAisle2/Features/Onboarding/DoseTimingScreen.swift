import SwiftUI

struct DoseTimingScreen: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

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
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 50)
                .padding(.top, 16)
                .padding(.bottom, 20)

            Text("Dose and timing")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .tracking(0.3)
                .padding(.bottom, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Dose input
                    VStack(spacing: 8) {
                        Text("CURRENT DOSE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                            .tracking(1.2)

                        TextField("e.g. 0.5mg", text: Binding(
                            get: { profile.doseAmount ?? "" },
                            set: { profile.doseAmount = $0 }
                        ))
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .keyboardType(.decimalPad)
                    }

                    // Modality-specific
                    if modality == .injectable {
                        injectableSection
                    } else {
                        oralSection
                    }

                    // Mira note
                    HStack(spacing: 10) {
                        MiraWaveform(state: .idle, size: .compact)
                        Text(modality == .injectable
                            ? "I'll adjust your meals based on where you are in your cycle."
                            : "I'll plan meals around your pill timing for best absorption.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 28)
            }

            GlowButton("Continue") {
                profile.modality = modality
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Injectable

    private var injectableSection: some View {
        VStack(spacing: 20) {
            // Frequency
            VStack(spacing: 8) {
                Text("HOW OFTEN")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1.2)

                HStack(spacing: 6) {
                    frequencyOption("Once a week", value: 1)
                    frequencyOption("Twice a week", value: 2)
                }
            }

            // Injection day(s)
            VStack(spacing: 8) {
                Text("INJECTION DAY")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1.2)

                HStack(spacing: 4) {
                    ForEach(Array(zip(1...7, ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])), id: \.0) { day, label in
                        let isSelected = profile.injectionDay == day

                        Button {
                            HapticManager.selection()
                            withAnimation(.easeOut(duration: 0.12)) {
                                profile.injectionDay = day
                            }
                        } label: {
                            Text(label)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.35))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? Color.violet.opacity(0.2) : .white.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isSelected ? Color.violet.opacity(0.4) : .clear, lineWidth: 0.5)
                                )
                                .shadow(color: isSelected ? Color.violet.opacity(0.15) : .clear, radius: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func frequencyOption(_ label: String, value: Int) -> some View {
        let isSelected = (profile.injectionsPerWeek ?? 1) == value

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.12)) {
                profile.injectionsPerWeek = value
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.violet.opacity(0.18) : .white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.violet.opacity(0.4) : .clear, lineWidth: 0.5)
                )
                .shadow(color: isSelected ? Color.violet.opacity(0.2) : .clear, radius: 12, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Oral

    private var oralSection: some View {
        VStack(spacing: 20) {
            // Times per day
            VStack(spacing: 8) {
                Text("HOW MANY TIMES A DAY")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1.2)

                HStack(spacing: 6) {
                    pillFrequencyOption("Once daily", value: 1)
                    pillFrequencyOption("Twice daily", value: 2)
                    pillFrequencyOption("Three times", value: 3)
                }
            }

            // Pill time
            if modality == .oralWithFasting {
                VStack(spacing: 8) {
                    Text("WHAT TIME DO YOU TAKE IT")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(1.2)

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
                    .frame(height: 110)
                    .clipped()

                    Text("Take on empty stomach. Wait 30 minutes before eating.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            } else {
                // Foundayo - no fasting
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x34D399))
                        .font(.system(size: 18))

                    Text("No fasting required. Take with or without food.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0x34D399).opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0x34D399).opacity(0.12), lineWidth: 0.5)
                )
            }
        }
    }

    private func pillFrequencyOption(_ label: String, value: Int) -> some View {
        let isSelected = (profile.pillTimesPerDay ?? 1) == value

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.12)) {
                profile.pillTimesPerDay = value
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.violet.opacity(0.18) : .white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.violet.opacity(0.4) : .clear, lineWidth: 0.5)
                )
                .shadow(color: isSelected ? Color.violet.opacity(0.2) : .clear, radius: 12, y: 2)
        }
        .buttonStyle(.plain)
    }
}
