import SwiftUI

enum ProgressCategory {
    case protein
    case water
    case fiber
    case calories

    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .protein: Theme.Semantic.protein(for: scheme)
        case .water: Theme.Semantic.water(for: scheme)
        case .fiber: Theme.Semantic.fiber(for: scheme)
        case .calories: Theme.Semantic.calories(for: scheme)
        }
    }
}

struct ProgressBar: View {
    @Environment(\.colorScheme) private var scheme

    let progress: Double
    let category: ProgressCategory
    let height: CGFloat

    init(progress: Double, category: ProgressCategory, height: CGFloat = 6) {
        self.progress = min(max(progress, 0), 1)
        self.category = category
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(category.color(for: scheme).opacity(0.12))

                // Fill
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                category.color(for: scheme),
                                category.color(for: scheme).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(Theme.Motion.spring, value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Labeled Variant

struct LabeledProgressBar: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    let current: Double
    let target: Double
    let unit: String
    let category: ProgressCategory

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))

                Spacer()

                Text("\(Int(current))/\(Int(target))\(unit)")
                    .font(Typography.monoSmall)
                    .foregroundStyle(category.color(for: scheme))
            }

            ProgressBar(
                progress: target > 0 ? current / target : 0,
                category: category
            )
        }
    }
}
