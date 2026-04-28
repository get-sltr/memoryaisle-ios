import SwiftUI

struct HairlineDivider: View {
    var opacity: Double = 0.45

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .frame(height: 0.5)
    }
}
