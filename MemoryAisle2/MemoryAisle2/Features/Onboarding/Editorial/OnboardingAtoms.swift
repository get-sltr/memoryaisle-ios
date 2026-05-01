import SwiftUI

// MARK: - Scaffold (gradient + fireflies + chrome + content slot)

/// Editorial onboarding scaffold. Locked to night gradient + fireflies per
/// the mockup — onboarding has no MAMode toggle. Each screen wraps its
/// content in this scaffold; the scaffold provides the editorial canvas,
/// the masthead bar (progress + SKIP), and per-screen padding.
struct OnboardingScaffold<Content: View>: View {
    let progress: Double
    let onSkip: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Theme.Editorial.nightGradient
                .ignoresSafeArea()

            FirefliesLayer()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                OnboardingChrome(progress: progress, onSkip: onSkip)
                    .padding(.bottom, 18)

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, Theme.Editorial.Spacing.topInset)
            .padding(.bottom, 30)
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Chrome (progress bar + universal SKIP)

struct OnboardingChrome: View {
    let progress: Double
    let onSkip: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Hairline progress, fills left to right per the mockup.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Editorial.onSurface.opacity(0.15))
                    Rectangle()
                        .fill(Theme.Editorial.onSurface.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                }
                .clipShape(Capsule())
            }
            .frame(height: 2)

            if let onSkip {
                Button(action: onSkip) {
                    Text("SKIP")
                        .font(Theme.Editorial.Typography.capsBold(9))
                        .tracking(2.2)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip this step")
            }
        }
    }
}

// MARK: - Question + Helper (Caslon serif)

struct OnboardingQuestion: View {
    let lines: [QuestionLine]
    var size: CGFloat = 24

    init(_ text: String, italic: Bool = false, size: CGFloat = 24) {
        self.lines = [QuestionLine(text: text, italic: italic)]
        self.size = size
    }

    init(lines: [QuestionLine], size: CGFloat = 24) {
        self.lines = lines
        self.size = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
                Text(line.text)
                    .font(.system(size: size, weight: .regular, design: .serif))
                    .italic(line.italic)
            }
        }
        .kerning(-0.012 * size)
        .lineSpacing(-2)
        .foregroundStyle(Theme.Editorial.onSurface)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct QuestionLine: Identifiable, Sendable {
    let id = UUID()
    let text: String
    var italic: Bool = false
}

struct OnboardingHelper: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Editorial.Typography.miraBody())
            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Choice button (rank-aware)

struct OnboardingChoice: View {
    let title: String
    var subtitle: String? = nil
    var isSelected: Bool = false
    var rank: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Editorial.Typography.miraBody())
                            .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                    }
                }
                Spacer(minLength: 8)
                if let rank {
                    Text("\(rank)")
                        .font(Theme.Editorial.Typography.capsBold(10))
                        .foregroundStyle(Theme.Editorial.nightTop)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.Editorial.onSurface))
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Editorial.onSurface.opacity(isSelected ? 0.15 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Theme.Editorial.onSurface.opacity(isSelected ? 0.95 : 0.18),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Chip (multi-select)

struct OnboardingChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(Theme.Editorial.onSurface.opacity(isSelected ? 0.18 : 0.06))
                )
                .overlay(
                    Capsule().stroke(
                        Theme.Editorial.onSurface.opacity(isSelected ? 0.9 : 0.2),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct OnboardingChipRow: View {
    let chips: [String]
    let selection: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        OnboardingChipFlow(spacing: 6) {
            ForEach(chips, id: \.self) { chip in
                OnboardingChip(
                    title: chip,
                    isSelected: selection.contains(chip),
                    action: { onToggle(chip) }
                )
            }
        }
    }
}

// MARK: - Buttons

struct OnboardingPrimaryButton: View {
    let title: String
    var trailingArrow: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                    .font(.system(size: trailingArrow ? 12 : 11, weight: .heavy, design: .monospaced))
                    .tracking(trailingArrow ? 4.8 : 2.2)
                if trailingArrow { Text("→").font(.system(size: 14)) }
            }
            .foregroundStyle(disabled
                ? Theme.Editorial.onSurface.opacity(0.5)
                : Theme.Editorial.nightTop)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(disabled
                    ? Theme.Editorial.onSurface.opacity(0.18)
                    : Theme.Editorial.onSurface)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(title)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    Capsule().stroke(Theme.Editorial.onSurface.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Number pill (numeric input)

struct OnboardingNumberPill: View {
    @Binding var text: String
    var placeholder: String = ""
    var helper: String = ""
    var keyboardType: UIKeyboardType = .numberPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(Theme.Editorial.onSurface.opacity(0.4))
                    .italic()
            )
            .font(.system(size: 22, weight: .regular, design: .serif))
            .foregroundStyle(Theme.Editorial.onSurface)
            .keyboardType(keyboardType)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Editorial.onSurface.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Editorial.onSurface.opacity(0.25), lineWidth: 1)
            )

            if !helper.isEmpty {
                Text(helper)
                    .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
        }
    }
}

// MARK: - Multi-line text input + voice button

/// Captures free-text answers (Screens 03 and 10). The TextField is the
/// primary input — tap it to type. The voice button below is an alternate
/// affordance for users who'd rather speak; it drives `VoiceManager` (Apple
/// Speech framework) in push-to-talk mode and replaces `text` with the live
/// transcript while listening. No new STT path is built — this view
/// delegates entirely to the existing manager. The "OR" prefix on the voice
/// button label and the modeHint line above it both signal that typing
/// works for users who can't speak aloud.
struct OnboardingTextInput: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 130
    let voice: VoiceManager
    @Binding var isListening: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(Theme.Editorial.onSurface.opacity(0.4))
                    .italic(),
                axis: .vertical
            )
            .font(.system(size: 14, weight: .regular, design: .serif).italic())
            .foregroundStyle(Theme.Editorial.onSurface)
            .lineLimit(4...8)
            .padding(14)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Editorial.onSurface.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Editorial.onSurface.opacity(0.25), lineWidth: 1)
            )

            modeHint

            HStack {
                voiceButton
                Spacer()
            }
        }
        .onChange(of: voice.transcribedText) { _, new in
            // Live transcript replaces field text while listening so the
            // user sees what the recognizer hears.
            if isListening, !new.isEmpty {
                text = new
            }
        }
    }

    private var modeHint: some View {
        Text("TAP THE FIELD TO TYPE — OR HOLD THE MIC TO SPEAK")
            .font(Theme.Editorial.Typography.caps(8, weight: .medium))
            .tracking(1.6)
            .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            .accessibilityHidden(true)
    }

    private var voiceButton: some View {
        Button {
            Task { await togglePushToTalk() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11))
                Text(isListening ? "RELEASE WHEN DONE" : "OR HOLD TO SPEAK")
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(1.8)
            }
            .foregroundStyle(Theme.Editorial.onSurface)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                Capsule().fill(Theme.Editorial.onSurface.opacity(0.10))
            )
            .overlay(
                Capsule().stroke(Theme.Editorial.onSurface.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.05)
                .onChanged { _ in startListeningIfIdle() }
                .onEnded { _ in stopListeningIfActive() }
        )
        .accessibilityLabel(isListening ? "Release when done speaking" : "Hold to speak, or tap the field above to type")
    }

    private func startListeningIfIdle() {
        guard !isListening else { return }
        HapticManager.light()
        voice.transcribedText = ""
        voice.startListening()
        isListening = true
    }

    private func stopListeningIfActive() {
        guard isListening else { return }
        voice.stopListening()
        isListening = false
        if !voice.transcribedText.isEmpty {
            text = voice.transcribedText
        }
    }

    private func togglePushToTalk() async {
        // The button's primary action is a tap fallback for accessibility;
        // the real interaction is the simultaneousGesture LongPress.
    }
}

// MARK: - Mira mark (bars + sparkle)

struct OnboardingMiraMark: View {
    var body: some View {
        HStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach([0.38, 0.64, 1.0, 0.60, 0.32], id: \.self) { ratio in
                    Capsule()
                        .fill(Theme.Editorial.onSurface)
                        .frame(width: 3, height: CGFloat(ratio) * 26)
                        .shadow(color: .white.opacity(0.4), radius: 6)
                }
            }
            .frame(height: 26)

            Text("\u{2726}")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Editorial.onSurface)
                .shadow(color: .white.opacity(0.4), radius: 6)
                .padding(.leading, 4)
        }
    }
}

// MARK: - Section label (caps bold, used inside multi-section screens)

struct OnboardingSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Editorial.Typography.capsBold(9))
            .tracking(2.2)
            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
    }
}

// MARK: - Flow layout (for chips wrapping across rows)

/// Minimal flow layout — needed because SwiftUI doesn't ship a native
/// HStack-that-wraps. Used by `OnboardingChipRow`. Single-pass layout,
/// no caching, fine for the chip count we render (under 20).
struct OnboardingChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
