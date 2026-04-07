import SwiftUI

struct MiraReadyScreen: View {
    let profile: OnboardingProfile
    let onComplete: () -> Void
    @State private var miraState: MiraState = .thinking
    @State private var showContent = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MiraWaveform(state: miraState, size: .hero)
                .frame(height: 70)
                .padding(.bottom, 44)

            if showContent {
                VStack(spacing: 28) {
                    Text("You're all set.")
                        .font(.system(size: 30, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                        .tracking(0.5)

                    VStack(spacing: 10) {
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
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 36)

                    Text(closingMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .transition(.opacity.combined(with: .offset(y: 24)))
            }

            Spacer()

            if showButton {
                GlowButton("Take me home") {
                    HapticManager.success()
                    onComplete()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(1.0)) {
                miraState = .speaking
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(2.0)) {
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
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    private var derivedMode: String {
        if !profile.isOnGLP1 {
            if profile.trainingLevel == .lifts { return "Muscle Preservation" }
            return "Smart Nutrition"
        }
        if profile.worries.contains(.nausea) { return ProductMode.sensitiveStomach.rawValue }
        if profile.trainingLevel == .lifts { return ProductMode.musclePreservation.rawValue }
        return ProductMode.everyday.rawValue
    }

    private var closingMessage: String {
        if !profile.isOnGLP1 {
            return "I'll build your meal plans around your goals\nand make sure every bite counts."
        }
        if profile.worries.contains(.nausea) {
            return "I'll focus on gentle, nausea-friendly meals\nthat still hit your protein targets."
        }
        if profile.trainingLevel == .lifts {
            return "I'll fuel your training with the right protein\nat the right times to preserve muscle."
        }
        return "I'll plan your meals around your medication cycle\nand make sure every bite counts."
    }
}
