import SwiftUI

/// Editorial Pro-features list rendered as the section between the hero
/// and the plan cards on PaywallView. Ten rows, each a single-line label
/// with a checkmark trailing, separated by faint hairlines.
///
/// Feature labels are sourced from the App-Review-approved feature list and
/// must stay aligned with what marketing/PR has described as "Pro" in
/// outreach materials.
struct PaywallFeatureList: View {
    private static let features: [String] = [
        "Unlimited barcode scans",
        "Full adaptive meal planning",
        "Unlimited Mira conversations",
        "Grocery list generation",
        "Body composition tracking",
        "Training-day adjustments",
        "Symptom pattern analysis",
        "Provider report PDF",
        "Lock screen widgets",
        "All product modes"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Self.features.indices, id: \.self) { index in
                row(Self.features[index])
                if index < Self.features.count - 1 {
                    HairlineDivider().opacity(0.25)
                }
            }
        }
    }

    private func row(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 4)
    }
}
