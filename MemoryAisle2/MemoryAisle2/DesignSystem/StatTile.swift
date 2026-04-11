import SwiftUI

// Bold stat card — the "pop" element that goes on every dashboard.
// Big number + uppercase label + optional sub-caption.
// Reads section from environment unless overridden.
struct StatTile: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let label: String
    let value: String
    let sub: String?
    let sectionOverride: SectionID?

    init(
        label: String,
        value: String,
        sub: String? = nil,
        section: SectionID? = nil
    ) {
        self.label = label
        self.value = value
        self.sub = sub
        self.sectionOverride = section
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Typography.label)
                .tracking(1.2)
                .foregroundStyle(SectionPalette.soft(effectiveSection))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(Color(.label))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 96)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Color.indigoBlack)
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Section.tile(effectiveSection, for: scheme))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Section.glow(effectiveSection, for: scheme), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)\(sub.map { ", \($0)" } ?? "")")
    }
}

#Preview("StatTile grid — dark") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                HStack(spacing: 12) {
                    StatTile(label: "Items", value: "24", sub: "3 expiring").section(id)
                    StatTile(label: "Protein", value: "128g", sub: "of 180").section(id)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}

#Preview("StatTile grid — light") {
    HStack(spacing: 12) {
        StatTile(label: "Items", value: "24", sub: "3 expiring").section(.pantry)
        StatTile(label: "Recipes", value: "12").section(.recipes)
    }
    .padding()
    .background(Color.white)
    .preferredColorScheme(.light)
}
