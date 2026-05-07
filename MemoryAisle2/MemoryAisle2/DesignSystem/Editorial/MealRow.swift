import SwiftUI

struct MealRow: View {
    let time: String
    let name: String
    let proteinGrams: Int
    let calories: Int
    let prepMinutes: Int
    /// Adherence state for the row. Drives the visual treatment:
    /// .open → standard rendering, .eaten → checkmark prefix +
    /// "LOGGED HH:MM" caps line, .skipped → strikethrough name +
    /// "SKIPPED HH:MM" caps line, .swapped → strikethrough name +
    /// "ATE: <name> · HH:MM" caps line.
    var adherence: AdherenceState = .open
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if case .eaten = adherence {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.Editorial.onSurface)
                    }
                    Text(time)
                        .font(Theme.Editorial.Typography.capsBold(9))
                        .tracking(2.2)
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .opacity(0.85)
                }

                Text(name)
                    .font(Theme.Editorial.Typography.mealName())
                    .kerning(-0.3)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .opacity(adherence.dimsName ? 0.5 : 1.0)
                    .strikethrough(adherence.strikesName)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let line = adherence.statusLine {
                    Text(line)
                        .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                }

                HStack(spacing: 16) {
                    MacroLabel(value: "\(proteinGrams)", unit: "g protein")
                    MacroLabel(value: "\(calories)", unit: " cal")
                    MacroLabel(value: "\(prepMinutes)", unit: " min")
                }
                .opacity(adherence.dimsName ? 0.55 : 1.0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Editorial.hairlineSoft)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let base = "\(time), \(name), \(proteinGrams) grams protein, \(calories) calories, \(prepMinutes) minutes"
        switch adherence {
        case .open:                     return base
        case .eaten:                    return "Logged. \(base)"
        case .skipped:                  return "Skipped. \(base)"
        case .swapped(let to, _):       return "Swapped for \(to). \(base)"
        }
    }
}

extension AdherenceState {
    /// HH:MM in the user's locale. Cheap; renders inline in the caps
    /// status line (".LOGGED 7:32 PM").
    fileprivate static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    fileprivate var statusLine: String? {
        switch self {
        case .open:                       return nil
        case .eaten(let at):              return "LOGGED \(Self.timeString(at).uppercased())"
        case .skipped(let at):            return "SKIPPED \(Self.timeString(at).uppercased())"
        case .swapped(let to, let at):    return "ATE: \(to.uppercased()) · \(Self.timeString(at).uppercased())"
        }
    }

    fileprivate var strikesName: Bool {
        switch self {
        case .skipped, .swapped: return true
        default: return false
        }
    }

    fileprivate var dimsName: Bool {
        switch self {
        case .skipped, .swapped: return true
        default: return false
        }
    }
}
