import SwiftUI

/// Unified moment card. Single component, dispatches background, border,
/// and badge variant via moment.category. Renders a top row with
/// week/date label and optional badge, optional photo (4:3 aspect),
/// title, description, optional user quote in italic serif, and an
/// optional metadata footnote in micro tracked label style.
struct MomentCard: View {
    let moment: ReflectionMoment

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topRow
            photoIfPresent
            Text(moment.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
            if let description = moment.description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let quote = moment.quote {
                quoteBlock(quote)
            }
            if let metadata = moment.metadataLabel {
                metadataFootnote(metadata)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorder, lineWidth: Theme.glassBorderWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(moment.title). \(moment.description ?? "")")
    }

    private var topRow: some View {
        HStack {
            Text(formattedDate)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(Theme.Text.hint(for: scheme))
            Spacer()
            if let badgeVariant = badgeVariant {
                MomentBadge(variant: badgeVariant)
            }
        }
    }

    @ViewBuilder
    private var photoIfPresent: some View {
        if let photoData = moment.photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .aspectRatio(4 / 3, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func quoteBlock(_ quote: String) -> some View {
        Text("\u{201C}\(quote)\u{201D}")
            .font(.system(size: 13, design: .serif).italic())
            .foregroundStyle(Theme.Text.secondary(for: scheme))
            .padding(.top, 4)
    }

    private func metadataFootnote(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .tracking(1.0)
            .foregroundStyle(Theme.Text.hint(for: scheme))
            .padding(.top, 2)
    }

    private var cardBackground: Color {
        switch moment.category {
        case .standard, .personalBest:
            return Theme.Surface.glass(for: scheme)
        case .milestone:
            return Theme.Semantic.onTrack(for: scheme).opacity(0.04)
        case .toughDay:
            return Theme.Semantic.warning(for: scheme).opacity(0.04)
        }
    }

    private var cardBorder: Color {
        switch moment.category {
        case .standard, .personalBest:
            return Theme.Border.glass(for: scheme)
        case .milestone:
            return Theme.Semantic.onTrack(for: scheme).opacity(0.12)
        case .toughDay:
            return Theme.Semantic.warning(for: scheme).opacity(0.12)
        }
    }

    private var badgeVariant: MomentBadge.Variant? {
        switch moment.category {
        case .standard: return nil
        case .milestone: return .milestone
        case .toughDay: return .toughDay
        case .personalBest: return .personalBest
        }
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: moment.date).uppercased()
    }
}
