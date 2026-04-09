import SwiftUI

struct BodyStatsScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var subStep = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch subStep {
                case 0: agePage
                case 1: sexEthnicityPage
                default: heightWeightPage
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(Theme.Motion.spring, value: subStep)
        }
    }

    // MARK: - Page 1: Age

    private var agePage: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingLogo()
                .padding(.bottom, 32)

            Text("How old are you?")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("This helps personalize your targets")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 8)

            TextField("e.g. 35", text: Binding(
                get: { profile.age.map { "\($0)" } ?? "" },
                set: { profile.age = Int($0) }
            ))
            .font(.system(size: 32, weight: .light, design: .monospaced))
            .foregroundStyle(Theme.Text.primary)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .padding(.vertical, 20)
            .padding(.horizontal, 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
            .padding(.horizontal, 60)
            .padding(.top, 40)

            Spacer()

            bottomButtons {
                withAnimation { subStep = 1 }
            }
        }
    }

    // MARK: - Page 2: Sex + Ethnicity

    private var sexEthnicityPage: some View {
        VStack(spacing: 0) {
            OnboardingLogo()
                .padding(.top, 16)
                .padding(.bottom, 24)

            Text("About you")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)
                .padding(.bottom, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    selectionField("BIOLOGICAL SEX") {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            selectionPill(sex.rawValue, isSelected: profile.sex == sex) {
                                profile.sex = sex
                            }
                        }
                    }

                    selectionField("ETHNICITY") {
                        ForEach(Ethnicity.allCases, id: \.self) { eth in
                            selectionPill(eth.rawValue, isSelected: profile.ethnicity == eth) {
                                profile.ethnicity = eth
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
            }

            bottomButtons {
                withAnimation { subStep = 2 }
            }
        }
    }

    // MARK: - Page 3: Height + Weight

    private var heightWeightPage: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingLogo()
                .padding(.bottom, 32)

            Text("Height and weight")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("Used to calculate your protein target")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 8)
                .padding(.bottom, 32)

            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    statField("HEIGHT (FT)", value: Binding(
                        get: {
                            guard let inches = profile.heightInches else { return "" }
                            return "\(inches / 12)"
                        },
                        set: {
                            let ft = Int($0) ?? 0
                            let existingIn = (profile.heightInches ?? 0) % 12
                            profile.heightInches = ft * 12 + existingIn
                        }
                    ), placeholder: "ft", keyboard: .numberPad)

                    statField("HEIGHT (IN)", value: Binding(
                        get: {
                            guard let inches = profile.heightInches else { return "" }
                            return "\(inches % 12)"
                        },
                        set: {
                            let inches = Int($0) ?? 0
                            let existingFt = (profile.heightInches ?? 0) / 12
                            profile.heightInches = existingFt * 12 + inches
                        }
                    ), placeholder: "in", keyboard: .numberPad)
                }

                HStack(spacing: 10) {
                    statField("CURRENT WEIGHT", value: Binding(
                        get: { profile.weightLbs.map { "\(Int($0))" } ?? "" },
                        set: { profile.weightLbs = Double($0) }
                    ), placeholder: "lbs", keyboard: .numberPad)

                    statField("GOAL WEIGHT", value: Binding(
                        get: { profile.goalWeightLbs.map { "\(Int($0))" } ?? "" },
                        set: { profile.goalWeightLbs = Double($0) }
                    ), placeholder: "lbs", keyboard: .numberPad)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            bottomButtons {
                onContinue()
            }
        }
    }

    // MARK: - Shared Components

    private func bottomButtons(action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            GlowButton("Continue") {
                action()
            }
            Button {
                action()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }

    private func statField(_ label: String, value: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(placeholder, text: value)
                .font(.system(size: 17))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .keyboardType(keyboard)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Surface.glass(for: scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
        }
    }

    @ViewBuilder
    private func selectionField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)

            FlowLayout(spacing: 6) {
                content()
            }
        }
    }

    private func selectionPill(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.12)) { action() }
        } label: {
            Text(text)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color(hex: 0xA78BFA).opacity(0.18) : Theme.Surface.glass(for: scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color(hex: 0xA78BFA).opacity(0.4) : .clear, lineWidth: 0.5)
                )
                .shadow(color: isSelected ? Color(hex: 0xA78BFA).opacity(0.15) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (wrapping pills)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
