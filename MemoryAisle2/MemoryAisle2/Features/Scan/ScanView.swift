import SwiftUI

struct ScanView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            // Camera placeholder
            Color.indigoBlack.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                // Viewfinder frame
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Color.violet.opacity(0.4), lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .overlay {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.violet.opacity(0.5))

                            Text("Point at a barcode")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                        }
                    }

                // Action buttons
                HStack(spacing: Theme.Spacing.md) {
                    GhostButtonCompact("Barcode", icon: "barcode") {}
                    VioletButtonCompact("Photo", icon: "camera.fill") {}
                    GhostButtonCompact("Manual", icon: "text.cursor") {}
                }

                Spacer()
                Spacer(minLength: 80)
            }
        }
    }
}
