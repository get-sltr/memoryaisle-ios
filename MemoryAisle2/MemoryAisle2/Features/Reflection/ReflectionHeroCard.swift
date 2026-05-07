import SwiftUI

/// Day 1 vs Today photo comparison hero. Two photos in a side-by-side
/// HStack with overlay labels at the bottom of each (label, weight,
/// date). Left card uses standard glass surface, right card uses the
/// elevated/strong glass to emphasize "Today" subtly.
struct ReflectionHeroCard: View {
    let photos: HeroPhotos

    @Environment(\.colorScheme) private var scheme
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            photoTile(
                data: photos.day1,
                label: "DAY 1",
                labelColor: Theme.Text.tertiary(for: scheme),
                weight: photos.day1Weight,
                date: photos.day1Date,
                background: Theme.Surface.glass(for: scheme),
                border: Theme.Border.glass(for: scheme)
            )
            photoTile(
                data: photos.today,
                label: "TODAY",
                labelColor: Color.violet,
                weight: photos.todayWeight,
                date: photos.todayDate,
                background: Theme.Surface.strong(section: .home, for: scheme),
                border: Theme.Border.strong(section: .home, for: scheme)
            )
        }
        .padding(.horizontal, 28)
    }

    private func photoTile(
        data: Data?,
        label: String,
        labelColor: Color,
        weight: Double?,
        date: Date?,
        background: Color,
        border: Color
    ) -> some View {
        ZStack(alignment: .bottom) {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(background)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(labelColor)
                HStack(spacing: 8) {
                    if let weight {
                        Text(formattedWeight(weight))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                    }
                    if let date {
                        Text(shortDate(date))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.7))
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(border, lineWidth: Theme.glassBorderWidth)
        )
        .accessibilityLabel("\(label) photo")
    }

    private func formattedWeight(_ lbs: Double) -> String {
        let displayValue = appState.unitSystem == .metric ? lbs * 0.45359237 : lbs
        return String(format: "%.1f \(WeightFormat.unit(system: appState.unitSystem))", displayValue)
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}
