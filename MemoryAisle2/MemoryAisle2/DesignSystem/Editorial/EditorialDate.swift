import Foundation

/// Number-style aware wrapper around `RomanNumeral` and `EnglishNumber`.
/// The editorial mastheads, day rail, and meal-plan progress copy used to
/// hard-code Roman numerals and English number-words; that doesn't read
/// for users outside the en-locale editorial pattern. This routes every
/// editorial number through the user's NumberStyle preference so a single
/// settings flip cascades everywhere.
enum EditorialDate {

    // MARK: Mastheads

    /// Day-mode masthead trailing — date.
    static func dateString(from date: Date, style: NumberStyle, calendar: Calendar = .current) -> String {
        switch style {
        case .roman:
            return RomanNumeral.dateString(from: date, calendar: calendar)
        case .arabic:
            // "DD · MM · YYYY" arabic — same separators as the roman variant
            // so the layout doesn't shift when the user toggles.
            let comps = calendar.dateComponents([.day, .month, .year], from: date)
            let day = String(format: "%02d", comps.day ?? 0)
            let month = String(format: "%02d", comps.month ?? 0)
            let year = "\(comps.year ?? 0)"
            return "\(day) · \(month) · \(year)"
        }
    }

    /// Night-mode masthead trailing — day, month, time.
    static func eveningString(from date: Date, style: NumberStyle, calendar: Calendar = .current) -> String {
        switch style {
        case .roman:
            return RomanNumeral.eveningString(from: date, calendar: calendar)
        case .arabic:
            let comps = calendar.dateComponents([.day, .month, .hour, .minute], from: date)
            let day = String(format: "%02d", comps.day ?? 0)
            let month = String(format: "%02d", comps.month ?? 0)
            let hour = String(format: "%02d", comps.hour ?? 0)
            let minute = String(format: "%02d", comps.minute ?? 0)
            return "\(day) · \(month) · \(hour):\(minute)"
        }
    }

    // MARK: Numerals

    /// Plain integer rendered as roman or arabic.
    static func numeral(_ value: Int, style: NumberStyle) -> String {
        switch style {
        case .roman:  return RomanNumeral.string(from: value)
        case .arabic: return "\(value)"
        }
    }

    /// "N° I" or "N° 1" — used by the meal-plan day rail mark.
    static func ordinal(_ value: Int, style: NumberStyle) -> String {
        "N° \(numeral(value, style: style))"
    }

    /// Spelled-out day word ("ONE", "TWO" ...) for roman; arabic just
    /// renders the numeral. Used by `MealsView.curatedLine` and the
    /// in-flight progress indicator ("DAY ONE OF SEVEN READY"
    /// vs "DAY 1 OF 7 READY").
    static func dayWord(_ value: Int, style: NumberStyle) -> String {
        switch style {
        case .roman:  return EnglishNumber.word(from: value).uppercased()
        case .arabic: return "\(value)"
        }
    }
}
