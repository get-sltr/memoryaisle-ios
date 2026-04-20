import SwiftUI

struct AppleHealthCard: View {
    @Environment(\.colorScheme) private var scheme
    @State private var healthKit = HealthKitManager()
    @State private var isConnecting = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var showSettingsPrompt = false

    private var isConnected: Bool {
        healthKit.latestWeight != nil || !healthKit.weightHistory.isEmpty
    }

    var body: some View {
        Button {
            Task { await handleTap() }
        } label: {
            HStack(spacing: 14) {
                iconCap

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Health")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Text.primary)

                    if isConnected, !healthKit.weightHistory.isEmpty {
                        Sparkline(
                            data: healthKit.weightHistory.suffix(10).map(\.value)
                        )
                        .stroke(
                            Color.violet.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                        .frame(height: 20)

                        Text("from Apple Health \u{00b7} read-only")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    } else if isConnected {
                        Text("Connected \u{00b7} no weight history yet")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    } else {
                        Text("Sync weight, lean mass, body fat")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }
                }

                Spacer(minLength: 8)

                trailingView
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isConnected
                            ? Color.violet.opacity(0.2)
                            : Theme.Border.glass(for: scheme),
                        lineWidth: Theme.glassBorderWidth
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isConnected ? "Apple Health connected" : "Connect Apple Health")
        .task { await silentRefresh() }
        .alert("Apple Health access needed", isPresented: $showSettingsPrompt) {
            Button("Open Settings") { healthKit.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable Apple Health for MemoryAisle in Settings to sync weight, lean mass, and body fat.")
        }
    }

    // MARK: - Subviews

    private var iconCap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.violet.opacity(isConnected ? 0.16 : 0.1))
                .frame(width: 48, height: 48)
                .shadow(
                    color: isConnected ? Color.violet.opacity(0.2) : .clear,
                    radius: 8
                )

            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.violet)
        }
        .animation(Theme.Motion.spring, value: isConnected)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isConnecting {
            ProgressView()
                .controlSize(.small)
                .tint(Color.violet)
        } else if isConnected {
            Circle()
                .fill(Theme.Semantic.onTrack(for: scheme))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Theme.Semantic.onTrack(for: scheme).opacity(0.3), lineWidth: 2)
                        .scaleEffect(pulseScale)
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        pulseScale = 2.2
                    }
                }
        } else {
            Text("Connect")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.violet)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.violet.opacity(0.14))
                )
        }
    }

    // MARK: - Actions

    private func silentRefresh() async {
        await healthKit.fetchLatestWeight()
        await healthKit.fetchWeightHistory()
    }

    private func handleTap() async {
        guard !isConnecting else { return }

        if isConnected {
            if let url = URL(string: "x-apple-health://") {
                await UIApplication.shared.open(url)
            }
            return
        }

        isConnecting = true
        HapticManager.light()
        await healthKit.requestAuthorization()
        isConnecting = false

        if isConnected {
            HapticManager.success()
        } else {
            showSettingsPrompt = true
        }
    }
}

// MARK: - Sparkline

private struct Sparkline: Shape {
    let data: [Double]

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2,
              let lo = data.min(),
              let hi = data.max(),
              hi - lo > 0
        else { return Path() }

        let range = hi - lo
        let stepX = rect.width / CGFloat(data.count - 1)

        var path = Path()
        for (i, value) in data.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height - CGFloat((value - lo) / range) * rect.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}
