import Foundation

enum RomanNumeral {

    /// Returns the Roman numeral string for `value`. Falls back to the
    /// decimal string for non-positive numbers, since Roman numerals
    /// have no representation for zero or negatives.
    static func string(from value: Int) -> String {
        guard value > 0 else { return "\(value)" }
        let pairs: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var n = value
        var out = ""
        for (num, sym) in pairs {
            while n >= num {
                n -= num
                out += sym
            }
        }
        return out
    }

    /// "DD · MM · YYYY" rendered as Roman numerals (e.g., "XXVII · IV · MMXXVI").
    static func dateString(from date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.day, .month, .year], from: date)
        let day = string(from: comps.day ?? 0)
        let month = string(from: comps.month ?? 0)
        let year = string(from: comps.year ?? 0)
        return "\(day) · \(month) · \(year)"
    }

    /// "DD · MM · HH:mm" — used in night mode where the year drops to time.
    static func eveningString(from date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.day, .month, .hour, .minute], from: date)
        let day = string(from: comps.day ?? 0)
        let month = string(from: comps.month ?? 0)
        let hour = String(format: "%02d", comps.hour ?? 0)
        let minute = String(format: "%02d", comps.minute ?? 0)
        return "\(day) · \(month) · \(hour):\(minute)"
    }
}
