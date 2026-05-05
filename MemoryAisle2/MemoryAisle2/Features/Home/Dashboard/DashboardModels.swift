import Foundation

// MARK: - Meal Recommendation

struct MealRecommendation: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let calories: Int
    let proteinG: Int
    let fatG: Int
    let carbsG: Int?
    let reasoning: String
    let ingredients: [String]
    let isDoseDayFriendly: Bool

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        proteinG: Int,
        fatG: Int,
        carbsG: Int? = nil,
        reasoning: String,
        ingredients: [String] = [],
        isDoseDayFriendly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.reasoning = reasoning
        self.ingredients = ingredients
        self.isDoseDayFriendly = isDoseDayFriendly
    }

    /// Formatted line: "~520 CAL · 38G PROTEIN · 14G FAT"
    var macroLine: String {
        "~\(calories) CAL · \(proteinG)G PROTEIN · \(fatG)G FAT"
    }

    /// Three follow-up chips for the "Tell me more" Mira card. Derived from
    /// the recommendation so the swap question reflects the actual primary
    /// protein (e.g. "Can I swap salmon for tofu?" on a salmon dish, not
    /// the chicken default the static list used to show).
    var dynamicFollowUps: [String] {
        let haystack = (name + " " + ingredients.joined(separator: " ")).lowercased()
        let swap = Self.proteinSwaps.first { pair in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: pair.0))\\b"
            return haystack.range(of: pattern, options: .regularExpression) != nil
        }
        let swapQuestion = swap.map { "Can I swap \($0.0) for \($0.1)?" }
            ?? "Can I make this lighter?"
        let whyQuestion = isDoseDayFriendly
            ? "Why is this dose-day friendly?"
            : "Why does this fit my plan?"
        return [swapQuestion, "Show me something heartier.", whyQuestion]
    }

    /// Longest phrases first so multi-word matches ("cottage cheese",
    /// "greek yogurt") win over plain "yogurt"/"cheese" substrings.
    private static let proteinSwaps: [(String, String)] = [
        ("cottage cheese", "Greek yogurt"),
        ("greek yogurt", "cottage cheese"),
        ("salmon", "tofu"),
        ("tuna", "chicken"),
        ("halibut", "chicken"),
        ("tilapia", "tofu"),
        ("trout", "tofu"),
        ("cod", "chicken"),
        ("shrimp", "tofu"),
        ("chicken", "tofu"),
        ("turkey", "tofu"),
        ("steak", "chicken"),
        ("beef", "chicken"),
        ("pork", "chicken"),
        ("lamb", "chicken"),
        ("bison", "chicken"),
        ("tempeh", "tofu"),
        ("seitan", "tofu"),
        ("tofu", "chicken"),
        ("lentils", "chickpeas"),
        ("chickpeas", "tofu"),
        ("edamame", "tofu"),
        ("beans", "lentils"),
        ("eggs", "Greek yogurt"),
        ("egg", "Greek yogurt"),
        ("yogurt", "cottage cheese"),
    ]
}

// MARK: - Time-of-day window

enum MealWindow: String, Sendable {
    case breakfast, lunch, snack, dinner, lateNight

    /// Maps a Date's hour to the appropriate meal window.
    static func current(at date: Date = Date(), calendar: Calendar = .current) -> MealWindow {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .breakfast
        case 11..<14: return .lunch
        case 14..<17: return .snack
        case 17..<21: return .dinner
        default:      return .lateNight
        }
    }

    var eyebrowText: String {
        switch self {
        case .breakfast: return "RECOMMENDED FOR BREAKFAST"
        case .lunch:     return "RECOMMENDED FOR LUNCH"
        case .snack:     return "RECOMMENDED FOR A SNACK"
        case .dinner:    return "RECOMMENDED FOR DINNER"
        case .lateNight: return "A LIGHT BITE BEFORE BED"
        }
    }

    /// Default `RecipeCategory.rawValue` for a window. Used when a Mira
    /// suggestion is favorited so the saved entry slots into a sensible
    /// recipe category for the legacy filters.
    var recipeCategoryRaw: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .snack:     return "Snack"
        case .dinner:    return "Dinner"
        case .lateNight: return "Snack"
        }
    }
}

// MARK: - Expandable section identifier

enum DashboardSection: String, Identifiable, CaseIterable, Sendable {
    case dailyTargets, meals, feeling

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dailyTargets: return "DAILY TARGETS"
        case .meals:        return "MEALS"
        case .feeling:      return "FEELING"
        }
    }
}

// MARK: - Card type

enum DashboardCard: String, Identifiable, Sendable {
    case log, order, mira

    var id: String { rawValue }
}

// MARK: - Feeling state

enum Feeling: String, Identifiable, CaseIterable, Sendable {
    case good, nausea, noAppetite, fatigue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .good:        return "GOOD"
        case .nausea:      return "NAUSEA"
        case .noAppetite:  return "NO APP."
        case .fatigue:     return "FATIGUE"
        }
    }
}
