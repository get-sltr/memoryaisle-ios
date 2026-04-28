import SwiftUI

struct MacroLabel: View {
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 0) {
            Text(value)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
            Text(unit)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
        }
        .foregroundStyle(Theme.Editorial.onSurface)
        .opacity(0.85)
        .tracking(0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value)\(unit)")
    }
}
