import SwiftUI

/// Sheet header with a leading close button and a truly centered title.
///
/// Replaces the old `HStack { CloseButton; Spacer; Text; Spacer; Color.clear }`
/// pattern that appeared across seven sheets. In that pattern `Color.clear`
/// was a View with no explicit frame, so it claimed available horizontal
/// space like a Spacer, squeezed the right-side Spacer flat, and left the
/// title visibly off-center. This component uses a ZStack so the title
/// lays out on its own centered axis and the close button sits on a
/// leading-aligned overlay, which is stable regardless of title length
/// or Dynamic Type sizing.
///
/// CloseButton reads its theme from `@Environment(\.sectionID)`, so the
/// calling sheet's `.section(...)` modifier cascades into the button
/// without this component needing to plumb it through.
struct SheetHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
                .accessibilityAddTraits(.isHeader)

            HStack {
                CloseButton(action: onClose)
                Spacer()
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
