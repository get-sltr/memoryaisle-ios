import LocalAuthentication
import SwiftUI

struct BiometricGate<Content: View>: View {
    @State private var isUnlocked = false
    @State private var authError: String?
    @State private var lastAuthTime: Date?
    let timeout: TimeInterval
    let content: () -> Content

    init(
        timeout: TimeInterval = 300,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.timeout = timeout
        self.content = content
    }

    private var needsReauth: Bool {
        guard let last = lastAuthTime else { return true }
        return Date.now.timeIntervalSince(last) > timeout
    }

    var body: some View {
        Group {
            if isUnlocked && !needsReauth {
                content()
            } else {
                lockedView
            }
        }
        .onAppear { authenticate() }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.violet.opacity(0.6))

            Text("Protected Health Data")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)

            Text("Authenticate to view medication, body composition, and provider report data.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = authError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xF87171))
            }

            Button {
                authenticate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 16))
                    Text("Unlock")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.violet.opacity(0.3))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        Color.violet.opacity(0.4), lineWidth: 0.5
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x0A0914).ignoresSafeArea())
    }

    private var biometricIcon: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: nil
        )
        return context.biometryType == .faceID
            ? "faceid" : "touchid"
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        ) else {
            isUnlocked = true
            lastAuthTime = .now
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to view health data"
        ) { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    isUnlocked = true
                    lastAuthTime = .now
                    authError = nil
                } else {
                    authError = "Authentication failed. Tap to try again."
                }
            }
        }
    }
}

extension View {
    func biometricProtected(
        timeout: TimeInterval = 300
    ) -> some View {
        BiometricGate(timeout: timeout) { self }
    }
}
