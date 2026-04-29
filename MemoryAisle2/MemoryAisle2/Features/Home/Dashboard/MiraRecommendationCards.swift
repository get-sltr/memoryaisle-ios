import SwiftUI

/// Three pop-out cards triggered by the recommendation actions: Log, Order,
/// Mira. Cream-paper aesthetic, dark ink — inverts the gradient outside.
/// Presented as overlay sheets, animated up from the bottom of the dashboard.

// MARK: - Card chrome (locally scoped colors; promote to Theme.Editorial.Cards
// if these get reused on a second surface)

private extension Color {
    static let cardSurface = Color(red: 1.0, green: 0.988, blue: 0.961, opacity: 0.97)
    static let cardInk     = Color(red: 0.102, green: 0.102, blue: 0.114)
    static let cardInkMuted = Color(red: 0.546, green: 0.482, blue: 0.388)
    static let cardHairline = Color(red: 0.102, green: 0.102, blue: 0.114).opacity(0.12)
    static let cardChipBg  = Color(red: 0.961, green: 0.937, blue: 0.886)
}

private struct CardChrome<Content: View>: View {
    let eyebrow: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("— \(eyebrow)")
                    .font(Theme.Editorial.Typography.capsBold(8))
                    .tracking(2.2)
                    .foregroundStyle(Color.cardInkMuted)
                Spacer()
                Button(action: onClose) {
                    Text("✕")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.cardInk.opacity(0.6))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            content()
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18))
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: -8)
    }
}

// MARK: - LOG IT card

struct LogMealCard: View {
    let recommendation: MealRecommendation
    let onPhoto: () -> Void
    let onBarcode: () -> Void
    let onClose: () -> Void

    var body: some View {
        CardChrome(eyebrow: "LOG THIS MEAL", onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                Text(recommendation.name)
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Color.cardInk)

                HStack(spacing: 10) {
                    logOption(
                        icon: "camera.fill",
                        title: "TAKE A PHOTO",
                        desc: "Mira reads what's on the plate.",
                        primary: true,
                        action: onPhoto
                    )
                    logOption(
                        icon: "barcode.viewfinder",
                        title: "SCAN BARCODE",
                        desc: "For packaged foods.",
                        primary: false,
                        action: onBarcode
                    )
                }

                Text(recommendation.macroLine)
                    .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.cardInk.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    private func logOption(
        icon: String,
        title: String,
        desc: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(1.8)
                Text(desc)
                    .font(Theme.Editorial.Typography.miraBody())
                    .multilineTextAlignment(.center)
                    .opacity(0.75)
            }
            .foregroundStyle(primary ? Color.white : Color.cardInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(primary ? Color.cardInk : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(primary ? Color.cardInk : Color.cardInk.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ORDER IT card

struct OrderMealCard: View {
    let recommendation: MealRecommendation
    let installedApps: [DeliveryApp]
    let onTapApp: (DeliveryApp) -> Void
    let onClose: () -> Void

    var body: some View {
        CardChrome(eyebrow: "ORDER FROM", onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                Text(recommendation.name)
                    .font(Theme.Editorial.Typography.miraBody())
                    .foregroundStyle(Color.cardInk)

                if installedApps.isEmpty {
                    Text("No supported delivery apps detected on this device.")
                        .font(Theme.Editorial.Typography.body())
                        .foregroundStyle(Color.cardInk.opacity(0.7))
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(installedApps) { app in
                            Button {
                                onTapApp(app)
                            } label: {
                                HStack(spacing: 10) {
                                    Text(app.glyph)
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 28, height: 28)
                                        .background(app.tint)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Text(app.displayName)
                                        .font(Theme.Editorial.Typography.body())
                                        .foregroundStyle(Color.cardInk)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.cardInk.opacity(0.5))
                                }
                                .padding(.vertical, 12)
                                .overlay(alignment: .top) {
                                    Rectangle().fill(Color.cardHairline).frame(height: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.cardHairline).frame(height: 1)
                    }
                }

                Text("YOU ORDER IN YOUR OWN APP. WE DON'T SEE IT.\nMIRA WILL ASK IF YOU GOT IT.")
                    .font(Theme.Editorial.Typography.caps(7, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Color.cardInk.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - TELL ME MORE card (Mira speaks)

struct MiraTellMeMoreCard: View {
    let recommendation: MealRecommendation
    let followUps: [String]
    let onFollowUp: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        CardChrome(eyebrow: "MIRA", onClose: onClose) {
            VStack(alignment: .leading, spacing: 14) {
                miraBadge

                Text(recommendation.reasoning)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Color.cardInk)
                    .lineSpacing(2)

                if !recommendation.ingredients.isEmpty {
                    Text(recommendation.ingredients.joined(separator: " · ").uppercased())
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color.cardInkMuted)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.cardHairline).frame(height: 1)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.cardHairline).frame(height: 1)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(followUps, id: \.self) { question in
                        Button {
                            onFollowUp(question)
                        } label: {
                            Text("\u{201C}\(question)\u{201D}")
                                .font(Theme.Editorial.Typography.miraBody())
                                .foregroundStyle(Color.cardInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Capsule().fill(Color.cardChipBg)
                                )
                                .overlay(
                                    Capsule().stroke(Color.cardInk.opacity(0.10), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var miraBadge: some View {
        HStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach([0.38, 0.64, 1.0, 0.60, 0.32], id: \.self) { ratio in
                    Capsule()
                        .fill(Color.cardInk)
                        .frame(width: 2.5, height: CGFloat(ratio) * 22)
                }
            }
            .frame(height: 22)

            Text("\u{2726}")
                .font(.system(size: 12))
                .foregroundStyle(Color.cardInk)

            Text("SPEAKING")
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(2)
                .foregroundStyle(Color.cardInk)
        }
    }
}

// MARK: - Delivery app metadata

struct DeliveryApp: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let glyph: String
    let urlScheme: String
    let tint: Color

    /// Builds a deep link to search for the meal in the delivery app.
    /// Returns nil rather than force-unwrapping if the URL fails to construct.
    func deepLinkURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "search"
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        return components.url
    }

    static let supported: [DeliveryApp] = [
        DeliveryApp(
            id: "doordash", displayName: "DoorDash", glyph: "D",
            urlScheme: "doordash",
            tint: Color(red: 1.0, green: 0.188, blue: 0.031)
        ),
        DeliveryApp(
            id: "ubereats", displayName: "Uber Eats", glyph: "U",
            urlScheme: "ubereats",
            tint: Color(red: 0.024, green: 0.757, blue: 0.404)
        ),
        DeliveryApp(
            id: "grubhub", displayName: "Grubhub", glyph: "G",
            urlScheme: "grubhub",
            tint: Color(red: 0.965, green: 0.204, blue: 0.251)
        ),
        DeliveryApp(
            id: "instacart", displayName: "Instacart", glyph: "I",
            urlScheme: "instacart",
            tint: Color(red: 0.953, green: 0.420, blue: 0.024)
        )
    ]
}
