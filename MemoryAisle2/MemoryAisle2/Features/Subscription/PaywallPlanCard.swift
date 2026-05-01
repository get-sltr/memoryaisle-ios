import SwiftUI

/// Editorial plan card for PaywallView. One per subscription option.
/// Selected state fills with translucent white + thicker border. Optional
/// "BEST VALUE" pill anchored top-right with negative offset matches the
/// HTML mockup at /Users/KMiI/Desktop/memoryaisle_paywall_dark.html.
///
/// Subscription compliance copy (`periodLine`, "BEST VALUE", savings text)
/// is passed in by the parent verbatim from the App-Review-approved blob.
struct PaywallPlanCard: View {

    let title: String
    let priceText: String
    let periodLine: String
    let badge: String?
    let savings: String?
    let isSelected: Bool
    let onTap: () -> Void

    private static let goldAccent = Color(red: 0.96, green: 0.85, blue: 0.48)

    var body: some View {
        Button { onTap() } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.uppercased())
                        .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                        .tracking(2.8)
                        .foregroundStyle(
                            isSelected ? Theme.Editorial.onSurfaceMuted : Theme.Editorial.onSurfaceFaint
                        )

                    Text(priceText)
                        .font(Theme.Editorial.Typography.displayHero())
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(periodLine)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)

                    if let savings {
                        Text(savings.uppercased())
                            .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Self.goldAccent)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Theme.Editorial.onSurface : Theme.Editorial.onSurfaceFaint,
                            lineWidth: 1
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.Editorial.onSurface)
                            .frame(width: 11, height: 11)
                    }
                }
                .padding(.top, 6)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.Editorial.onSurface.opacity(0.04) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Editorial.onSurface.opacity(0.7) : Theme.Editorial.hairlineSoft,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge.uppercased())
                        .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                        .tracking(2.6)
                        .foregroundStyle(Self.goldAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Theme.Editorial.onSurface.opacity(0.7), lineWidth: 0.5)
                                )
                        )
                        .offset(x: -14, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) plan, \(priceText), \(periodLine)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
