import SwiftUI

/// Top-of-screen wordmark + trailing meta. Tap the wordmark to open the
/// app menu (the only path to features that aren't on the tab bar).
struct Masthead: View {
    let wordmark: String
    let trailing: String
    var onTapWordmark: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    onTapWordmark?()
                } label: {
                    Text(wordmark)
                        .font(Theme.Editorial.Typography.wordmark())
                        .tracking(4)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Editorial.onSurface)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(wordmark), open menu")
                .accessibilityHint("Opens the app menu")
                .disabled(onTapWordmark == nil)

                Spacer()

                Text(trailing)
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Editorial.onSurface)
            }
            HairlineDivider()
        }
    }
}
