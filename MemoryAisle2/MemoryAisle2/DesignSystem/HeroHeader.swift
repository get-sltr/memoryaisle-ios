import SwiftUI

// Top-of-page hero header with animated mesh gradient background.
// Approximately 220pt tall, title + optional subtitle, optional trailing slot.
struct HeroHeader<Trailing: View>: View {
    @Environment(\.sectionID) private var sectionID
    let title: String
    let subtitle: String?
    let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MeshGradientView(section: sectionID)
                .frame(height: 220)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    }
                }
                Spacer()
                VStack {
                    trailing()
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 20)
        }
        .frame(height: 220)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                style: .continuous
            )
        )
    }
}

extension HeroHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

#Preview("HeroHeader — each section") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(SectionID.allCases, id: \.self) { id in
                HeroHeader(
                    title: id.rawValue.capitalized,
                    subtitle: "\(Int.random(in: 5...30)) items · updated just now"
                ) {
                    CloseButton(action: {})
                }
                .section(id)
            }
        }
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
}
