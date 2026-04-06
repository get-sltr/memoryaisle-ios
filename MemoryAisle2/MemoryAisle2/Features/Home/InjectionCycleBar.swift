import SwiftData
import SwiftUI

struct InjectionCycleBar: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var injectionDay: Int? { profile?.injectionDay }

    private var phase: CyclePhase? {
        guard let day = injectionDay else { return nil }
        return InjectionCycleEngine.currentPhase(injectionDay: day)
    }

    var body: some View {
        if let phase, profile?.medicationModality == .injectable {
            GlassCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Medication Cycle")
                            .font(Typography.bodySmallBold)
                            .foregroundStyle(Theme.Text.primary)
                        Spacer()
                        Text(phase.rawValue)
                            .font(Typography.bodySmallBold)
                            .foregroundStyle(Theme.Accent.primary(for: scheme))
                    }

                    // Cycle bar
                    cycleBar

                    // Phase info
                    Text(phase.appetiteDescription)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))

                    Text(phase.proteinStrategy)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Accent.label(for: scheme))
                }
                .padding(Theme.Spacing.md)
            }
        }
    }

    private var cycleBar: some View {
        GeometryReader { geo in
            let progress = InjectionCycleEngine.progressInCycle(injectionDay: injectionDay ?? 1)

            ZStack(alignment: .leading) {
                // Track with phase segments
                HStack(spacing: 2) {
                    phaseSegment(width: geo.size.width * 0.14, color: Theme.Semantic.warning(for: scheme)) // Day 1
                    phaseSegment(width: geo.size.width * 0.28, color: Theme.Semantic.behind(for: scheme)) // Days 2-3
                    phaseSegment(width: geo.size.width * 0.28, color: Theme.Semantic.onTrack(for: scheme)) // Days 3-5
                    phaseSegment(width: geo.size.width * 0.15, color: Theme.Semantic.fiber(for: scheme)) // Days 5-6
                    phaseSegment(width: geo.size.width * 0.15, color: Theme.Text.secondary(for: scheme)) // Day 7
                }
                .opacity(0.2)

                // Progress fill
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.violet, Color.violetDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)

                // Current position dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.violet.opacity(0.5), radius: 4)
                    .offset(x: geo.size.width * progress - 5)
            }
        }
        .frame(height: 6)
    }

    private func phaseSegment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: max(0, width - 2))
    }
}
