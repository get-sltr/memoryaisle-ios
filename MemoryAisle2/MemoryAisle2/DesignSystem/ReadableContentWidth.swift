import SwiftUI

extension View {
    func readableContentWidth(max: CGFloat = 640) -> some View {
        self
            .frame(maxWidth: max)
            .frame(maxWidth: .infinity)
    }
}
