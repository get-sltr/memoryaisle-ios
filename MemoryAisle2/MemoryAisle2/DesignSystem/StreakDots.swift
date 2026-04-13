import SwiftUI

struct StreakDots: View {
    let activeDays: Set<Int>
    let dayCount: Int

    init(activeDays: Set<Int> = [], dayCount: Int = 7) {
        self.activeDays = activeDays
        self.dayCount = dayCount
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<dayCount, id: \.self) { index in
                Circle()
                    .fill(
                        activeDays.contains(index)
                            ? Theme.Semantic.streakActive
                            : Theme.Semantic.streakInactive
                    )
                    .frame(width: 8, height: 8)
            }
        }
    }
}
