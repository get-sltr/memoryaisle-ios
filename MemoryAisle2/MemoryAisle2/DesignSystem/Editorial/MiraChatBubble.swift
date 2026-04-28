import SwiftUI

/// Editorial chat bubble. Mira's turns are italic serif (left-aligned, 280pt
/// max width) with a leading sparkle + caps timestamp. User turns are
/// monospaced quotes (right-aligned, 260pt max width) with a trailing caps
/// timestamp. The visual contrast is the structural cue, not avatars or
/// rounded boxes.
struct MiraChatBubble: View {
    enum Author: Sendable { case mira, user }

    let author: Author
    let timestamp: String
    let text: String

    var body: some View {
        if author == .mira {
            miraTurn
        } else {
            userTurn
        }
    }

    private var miraTurn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text("✦")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                Text(timestamp)
                    .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
            Text(text)
                .font(Theme.Editorial.Typography.miraBody().weight(.medium))
                .foregroundStyle(Theme.Editorial.onSurface)
                .lineSpacing(2)
                .frame(maxWidth: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mira at \(timestamp): \(text)")
    }

    private var userTurn: some View {
        HStack {
            Spacer(minLength: 40)
            VStack(alignment: .trailing, spacing: 4) {
                Text(timestamp)
                    .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                Text("\u{201C}\(text)\u{201D}")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 260, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You at \(timestamp): \(text)")
    }
}
