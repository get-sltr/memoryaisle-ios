import SwiftUI

/// Night-mode meal row. Identical content to `MealRow` (time, name, macros)
/// but laid out with a leading checkmark dot and slightly muted body — the
/// evening recap reads as "this is what we did today" rather than "here's
/// what to make."
struct MealRowNight: View {
    let time: String
    let name: String
    let proteinGrams: Int
    let calories: Int
    /// Adherence state. Same semantics as MealRow.adherence — drives
    /// the leading checkmark dot's color, the strikethrough on swap/
    /// skip, and the status caps line below the meal name.
    var adherence: AdherenceState = .open
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(badgeFill)
                        .frame(width: 16, height: 16)
                    if showsCheckmark {
                        Text("✓")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Theme.Editorial.nightTop)
                    } else if showsSkippedSlash {
                        Image(systemName: "slash.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Editorial.onSurface)
                    }
                }
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 6) {
                    Text(time)
                        .font(Theme.Editorial.Typography.capsBold(9))
                        .tracking(2.2)
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .opacity(0.85)

                    Text(name)
                        .font(Theme.Editorial.Typography.mealName())
                        .kerning(-0.3)
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .opacity(nameOpacity)
                        .strikethrough(strikesName)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let line = statusLine {
                        Text(line)
                            .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    }

                    HStack(spacing: 16) {
                        MacroLabel(value: "\(proteinGrams)", unit: "g protein")
                        MacroLabel(value: "\(calories)", unit: " cal")
                    }
                    .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
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

    private var badgeFill: Color {
        switch adherence {
        case .eaten:                 return Theme.Editorial.onSurface
        case .skipped, .swapped:     return Theme.Editorial.onSurface.opacity(0.18)
        case .open:                  return Theme.Editorial.onSurface
        }
    }

    private var showsCheckmark: Bool {
        switch adherence {
        case .eaten, .open: return true
        default:            return false
        }
    }

    private var showsSkippedSlash: Bool {
        switch adherence {
        case .skipped, .swapped: return true
        default:                 return false
        }
    }

    private var nameOpacity: Double {
        switch adherence {
        case .eaten:               return 0.85
        case .skipped, .swapped:   return 0.4
        case .open:                return 0.65
        }
    }

    private var strikesName: Bool {
        switch adherence {
        case .skipped, .swapped: return true
        default: return false
        }
    }

    private var statusLine: String? {
        switch adherence {
        case .open:                                 return nil
        case .eaten(let at):                        return "LOGGED \(formatTime(at).uppercased())"
        case .skipped(let at):                      return "SKIPPED \(formatTime(at).uppercased())"
        case .swapped(let to, let at):              return "ATE: \(to.uppercased()) · \(formatTime(at).uppercased())"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var accessibilityLabel: String {
        let base = "\(time), \(name), \(proteinGrams) grams protein, \(calories) calories"
        switch adherence {
        case .open:                     return "\(base), completed"
        case .eaten:                    return "\(base), logged"
        case .skipped:                  return "\(base), skipped"
        case .swapped(let to, _):       return "\(base), swapped for \(to)"
        }
    }
}
