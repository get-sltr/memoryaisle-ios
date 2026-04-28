import SwiftUI

/// One labeled value inside `DailyTotalsRow`. Caps label on top, large serif
/// number, optional fainter unit. Left-aligned inside its share of the row.
struct TotalsStat: View {
    let label: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface)
                .opacity(0.75)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit ?? "")")
    }
}
