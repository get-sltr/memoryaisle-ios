import SwiftUI

struct MiraReadyScreen: View {
    let profile: OnboardingProfile
    let onComplete: () -> Void
    @State private var miraState: MiraState = .thinking
    @State private var showSummary = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MiraWaveform(state: miraState, size: .hero)
                .frame(height: 60)
                .padding(.bottom, 40)

            if showSummary {
                VStack(spacing: 24) {
                    Text("You're all set.")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)

                    // Summary
                    VStack(spacing: 12) {
                        if let med = profile.medication {
                            summaryRow("Medication", value: med.rawValue)
                        }
                        if let modality = profile.modality {
                            summaryRow("Type", value: modality.displayName)
                        }
                        summaryRow("Training", value: profile.trainingLevel.rawValue)
                        summaryRow("Mode", value: derivedMode)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .background(Color.violet.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 32)

                    Text("I'll plan your meals around your cycle\nand make sure every bite counts.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .transition(.opacity.combined(with: .offset(y: 20)))
            }

            Spacer()
            Spacer()

            if showButton {
                VioletButton("Take me home") {
                    HapticManager.success()
                    onComplete()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(1.2)) {
                miraState = .speaking
                showSummary = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(2.2)) {
                showButton = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    miraState = .idle
                }
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    private var derivedMode: String {
        if profile.worries.contains(.nausea) { return ProductMode.sensitiveStomach.rawValue }
        if profile.trainingLevel == .lifts { return ProductMode.musclePreservation.rawValue }
        return ProductMode.everyday.rawValue
    }
}
