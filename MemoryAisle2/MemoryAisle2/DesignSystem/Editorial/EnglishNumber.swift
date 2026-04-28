import Foundation

/// Spells small positive integers in English ("one", "two", ..., "twenty").
/// Falls back to the decimal string above 20 to keep editorial copy
/// readable without enumerating arbitrarily large numbers.
enum EnglishNumber {

    private static let words: [String] = [
        "zero", "one", "two", "three", "four", "five", "six",
        "seven", "eight", "nine", "ten", "eleven", "twelve",
        "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty"
    ]

    static func word(from value: Int) -> String {
        guard value >= 0, value < words.count else { return "\(value)" }
        return words[value]
    }
}
