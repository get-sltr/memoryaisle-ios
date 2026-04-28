import SwiftUI

struct LedgerRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface)
            Spacer()
            Text(value)
                .font(Theme.Editorial.Typography.dataValue())
                .tracking(0.5)
                .foregroundStyle(Theme.Editorial.onSurface)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(value)")
    }
}
