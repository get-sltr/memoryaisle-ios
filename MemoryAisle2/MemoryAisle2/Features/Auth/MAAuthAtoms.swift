import SwiftUI

// MARK: - Wordmark — MEMORYAISLE with sized-up M and A

/// Editorial wordmark for the auth surface. The two cap letters render at
/// ~140% the size of the surrounding letters (15pt vs 11pt serif medium),
/// which is the recognizable mark used throughout the auth flow's
/// mastheads. The smaller letters reuse `Theme.Editorial.Typography.wordmark()`
/// so the typography stays consistent with the in-app `Masthead`.
struct MAWordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            cap("M")
            small("E"); small("M"); small("O"); small("R"); small("Y")
            cap("A")
            small("I"); small("S"); small("L"); small("E")
        }
    }

    private func cap(_ c: String) -> some View {
        Text(c)
            .font(.system(size: 15, weight: .medium, design: .serif))
            .tracking(4)
            .foregroundStyle(Theme.Editorial.onSurface)
            .baselineOffset(-1)
    }

    private func small(_ c: String) -> some View {
        Text(c)
            .font(Theme.Editorial.Typography.wordmark())
            .tracking(4)
            .foregroundStyle(Theme.Editorial.onSurface)
    }
}

// MARK: - Top bar (BACK + centered wordmark)

struct MAAuthTopBar: View {
    var showBack: Bool = true
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if showBack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Text("←").font(.system(size: 14))
                            Text("BACK")
                                .font(Theme.Editorial.Typography.caps(12, weight: .semibold))
                                .tracking(1.8)
                        }
                        .foregroundStyle(Theme.Editorial.onSurface)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MAWordmark().layoutPriority(1)

            HStack { Spacer(minLength: 0) }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 32)
    }
}

// MARK: - Hero (two-line serif, italic second line)

struct MAAuthHero: View {
    let line1: String
    let line2: String
    var line2Italic: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(line1)
                .font(Theme.Editorial.Typography.displaySmall())
            Text(line2)
                .font(Theme.Editorial.Typography.displaySmall())
                .italic(line2Italic)
        }
        .kerning(-0.84)
        .lineSpacing(-4)
        .foregroundStyle(Theme.Editorial.onSurface)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Subtitle line (the editorial "— CAPS LINE" pattern)

struct MAAuthSub: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(Theme.Editorial.onSurface)
    }
}

// MARK: - Hairline-underline text field

struct MAAuthField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(Theme.Editorial.onSurface.opacity(0.5))
                    .italic()
            )
            .font(.system(size: 17, weight: .regular, design: .serif))
            .foregroundStyle(Theme.Editorial.onSurface)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(.vertical, 4)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.7))
                    .frame(height: 1)
            }
            .tint(Theme.Editorial.onSurface)
        }
    }
}

// MARK: - Password field with SHOW/HIDE

struct MAAuthPasswordField: View {
    let label: String
    @Binding var password: String
    var placeholder: String = "Enter your password"
    var textContentType: UITextContentType = .password
    @State private var isVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            HStack(alignment: .center, spacing: 12) {
                Group {
                    if isVisible {
                        TextField(
                            "",
                            text: $password,
                            prompt: Text(placeholder)
                                .foregroundColor(Theme.Editorial.onSurface.opacity(0.5))
                                .italic()
                        )
                    } else {
                        SecureField(
                            "",
                            text: $password,
                            prompt: Text(placeholder)
                                .foregroundColor(Theme.Editorial.onSurface.opacity(0.5))
                                .italic()
                        )
                    }
                }
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(Theme.Editorial.onSurface)

                Button { isVisible.toggle() } label: {
                    Text(isVisible ? "HIDE" : "SHOW")
                        .font(Theme.Editorial.Typography.capsBold(9))
                        .tracking(2.0)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            }
            .padding(.vertical, 4)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.7))
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Buttons

struct MAPrimaryButton: View {
    let title: String
    var trailingArrow: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                    .font(.system(
                        size: trailingArrow ? 12 : 11,
                        weight: .heavy,
                        design: .monospaced
                    ))
                    .tracking(trailingArrow ? 4.8 : 2.75)
                if trailingArrow { Text("→").font(.system(size: 14)) }
            }
            .foregroundStyle(Theme.Editorial.nightTop)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.Editorial.onSurface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct MASecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.75)
                .foregroundStyle(Theme.Editorial.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Theme.Editorial.onSurface.opacity(0.10))
                .overlay(
                    Capsule().stroke(
                        Theme.Editorial.onSurface.opacity(0.85),
                        lineWidth: 1
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Labeled divider

struct MALabeledDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Theme.Editorial.onSurface.opacity(0.65))
                .frame(height: 0.5)
            Text(label)
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2.7)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .fixedSize()
            Rectangle()
                .fill(Theme.Editorial.onSurface.opacity(0.65))
                .frame(height: 0.5)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Inline error message

struct MAAuthErrorLine: View {
    let message: String

    var body: some View {
        Text(message.uppercased())
            .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.85))
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Legal footer (preamble + tappable links)

/// Reuses the production `LegalView` sheet by surfacing each link as a
/// `LegalPage` callback. Production has five legal documents (Terms,
/// Privacy, Medical, Community, Data Policy) — Apple Review checks for
/// the medical disclaimer specifically — so the auth footer surfaces all
/// five rather than the reference's two.
struct MAAuthLegal: View {
    let preamble: String
    let onTap: (LegalPage) -> Void

    private struct Link: Identifiable {
        let id = UUID()
        let label: String
        let page: LegalPage
    }

    private let links: [Link] = [
        .init(label: "TERMS",     page: .terms),
        .init(label: "PRIVACY",   page: .privacy),
        .init(label: "MEDICAL",   page: .medical),
        .init(label: "COMMUNITY", page: .community),
        .init(label: "DATA",      page: .dataPolicy)
    ]

    var body: some View {
        VStack(spacing: 6) {
            Text(preamble)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            HStack(spacing: 8) {
                ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                    if index > 0 {
                        Text("·").foregroundStyle(Theme.Editorial.onSurfaceFaint)
                    }
                    Button { onTap(link.page) } label: {
                        Text(link.label)
                            .font(Theme.Editorial.Typography.capsBold(9))
                            .tracking(1.6)
                            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Theme.Editorial.onSurface.opacity(0.85))
                                    .frame(height: 0.5)
                                    .offset(y: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(link.label.lowercased())")
                }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading overlay

struct MALoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.Editorial.onSurface)
                .scaleEffect(1.2)
        }
        .accessibilityLabel("Loading")
    }
}
