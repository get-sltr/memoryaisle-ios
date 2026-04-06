import SwiftUI

struct ScanView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var scanLineOffset: CGFloat = -120

    var body: some View {
        ZStack {
            Color.indigoBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Scan")
                        .font(Typography.displaySmall)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

                Spacer()

                // Viewfinder with corner brackets
                ZStack {
                    // Corner brackets
                    ScannerCorners()
                        .stroke(Color.violet, lineWidth: 3)
                        .frame(width: 260, height: 260)

                    // Animated scan line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.violet.opacity(0),
                                    Color.violet.opacity(0.6),
                                    Color.violet.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 220, height: 2)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                            ) {
                                scanLineOffset = 120
                            }
                        }

                    // Center prompt
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.violet.opacity(0.3))

                        Text("Point at a barcode or food label")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                }

                Spacer()

                // Mode selector
                HStack(spacing: Theme.Spacing.md) {
                    scanModeButton("Barcode", icon: "barcode", isSelected: true)
                    scanModeButton("Photo", icon: "camera.fill", isSelected: false)
                    scanModeButton("Search", icon: "magnifyingglass", isSelected: false)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                // Capture button
                Button {
                    HapticManager.heavy()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.violet.opacity(0.4), lineWidth: 3)
                            .frame(width: 72, height: 72)

                        Circle()
                            .fill(Color.violet.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: "viewfinder")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.violet)
                    }
                }
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)

                Spacer(minLength: 80)
            }
        }
    }

    private func scanModeButton(_ title: String, icon: String, isSelected: Bool) -> some View {
        Button {
            HapticManager.selection()
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(Typography.caption)
            }
            .foregroundStyle(
                isSelected
                    ? Theme.Accent.primary(for: scheme)
                    : Theme.Text.tertiary(for: scheme)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                isSelected
                    ? Theme.Surface.strong(for: scheme)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
    }
}

// MARK: - Scanner Corner Brackets

struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength: CGFloat = 30
        let r: CGFloat = 8

        var path = Path()

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}
