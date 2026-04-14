import Foundation
import SwiftData

/// Executes Mira tool calls against the user's local SwiftData store.
///
/// Tool calls arrive as `(name: String, input: [String: AnyCodable])` from the
/// Lambda. The executor dispatches on name, validates inputs, performs the
/// SwiftData write or read, and returns a string tool_result that Claude
/// will see in the next turn of the conversation.
///
/// Each tool result is a short, factual string Claude can reference. We do
/// NOT return rich structured data — Claude parses the string back into
/// meaning via natural language. Keep tool result strings short and clear.
@MainActor
final class MiraToolExecutor {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Execute a single tool call and return a string result that will be
    /// sent back to Claude as the tool_result block.
    func execute(toolName: String, input: [String: Any]) -> String {
        switch toolName {
        case "addToGroceryList":
            return addToGroceryList(input: input)
        case "logMeal":
            return logMeal(input: input)
        case "getTodayNutrition":
            return getTodayNutrition()
        case "getUserTargets":
            return getUserTargets()
        default:
            return "Unknown tool: \(toolName)"
        }
    }

    // MARK: - addToGroceryList

    private func addToGroceryList(input: [String: Any]) -> String {
        guard let items = input["items"] as? [String], !items.isEmpty else {
            return "No items were provided to add."
        }

        // Fetch existing names to avoid duplicates
        let descriptor = FetchDescriptor<PantryItem>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map { $0.name.lowercased() })

        var added: [String] = []
        var skipped: [String] = []

        for raw in items {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if existingNames.contains(trimmed.lowercased()) {
                skipped.append(trimmed)
                continue
            }

            let item = PantryItem(
                name: trimmed,
                category: PantryCategorizer.categorize(trimmed)
            )
            context.insert(item)
            added.append(trimmed)
        }

        do {
            try context.save()
        } catch {
            return "Couldn't save grocery list: \(error.localizedDescription)"
        }

        if added.isEmpty && !skipped.isEmpty {
            return "All of those were already on the list: \(skipped.joined(separator: ", "))."
        }
        if skipped.isEmpty {
            return "Added \(added.count) items to the grocery list: \(added.joined(separator: ", "))."
        }
        return "Added \(added.count) items: \(added.joined(separator: ", ")). Already on the list: \(skipped.joined(separator: ", "))."
    }

    // MARK: - logMeal

    private func logMeal(input: [String: Any]) -> String {
        guard let name = input["name"] as? String, !name.isEmpty else {
            return "Need a meal name to log."
        }

        let protein = numberValue(input["proteinGrams"]) ?? 0
        let calories = numberValue(input["calories"]) ?? 0
        let fiber = numberValue(input["fiberGrams"]) ?? 0

        // Roll into today's NutritionLog if one exists, otherwise create it.
        let descriptor = FetchDescriptor<NutritionLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let logs = (try? context.fetch(descriptor)) ?? []
        let cal = Calendar.current
        let todayLog = logs.first { cal.isDateInToday($0.date) }

        if let existing = todayLog {
            existing.proteinGrams += protein
            existing.caloriesConsumed += calories
            existing.fiberGrams += fiber
        } else {
            let log = NutritionLog(
                date: .now,
                proteinGrams: protein,
                caloriesConsumed: calories,
                waterLiters: 0,
                fiberGrams: fiber
            )
            context.insert(log)
        }

        do {
            try context.save()
        } catch {
            return "Couldn't save meal log: \(error.localizedDescription)"
        }

        return "Logged \(name): \(Int(protein))g protein, \(Int(calories)) cal, \(Int(fiber))g fiber. Added to today's totals."
    }

    // MARK: - getTodayNutrition

    private func getTodayNutrition() -> String {
        let descriptor = FetchDescriptor<NutritionLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let logs = (try? context.fetch(descriptor)) ?? []
        let cal = Calendar.current
        guard let today = logs.first(where: { cal.isDateInToday($0.date) }) else {
            return "No meals logged yet today. Protein: 0g. Calories: 0. Water: 0L. Fiber: 0g."
        }
        return "Today so far — protein: \(Int(today.proteinGrams))g, calories: \(Int(today.caloriesConsumed)), water: \(String(format: "%.1f", today.waterLiters))L, fiber: \(Int(today.fiberGrams))g."
    }

    // MARK: - getUserTargets

    private func getUserTargets() -> String {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? context.fetch(descriptor)) ?? []
        guard let profile = profiles.first else {
            return "No user profile found yet."
        }

        var parts: [String] = [
            "Protein target: \(profile.proteinTargetGrams)g",
            "Calorie target: \(profile.calorieTarget)",
            "Water target: \(String(format: "%.1f", profile.waterTargetLiters))L",
            "Fiber target: \(profile.fiberTargetGrams)g"
        ]

        if let weight = profile.weightLbs {
            parts.append("Current weight: \(Int(weight)) lbs")
        }
        if let goal = profile.goalWeightLbs {
            parts.append("Goal weight: \(Int(goal)) lbs")
        }

        return parts.joined(separator: ". ") + "."
    }

    // MARK: - Helpers

    private func numberValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }
}

/// Auto-categorizes a grocery item name into a PantryCategory based on
/// keyword matching. Used by addToGroceryList when Mira adds items so they
/// end up in the right section of the list.
enum PantryCategorizer {
    static func categorize(_ name: String) -> PantryCategory {
        let lower = name.lowercased()
        if keyword(lower, in: ["chicken", "beef", "pork", "turkey", "lamb", "fish", "salmon", "tuna", "tofu", "tempeh", "egg", "eggs", "shrimp", "cod", "steak"]) {
            return .protein
        }
        if keyword(lower, in: ["apple", "banana", "berry", "spinach", "kale", "lettuce", "tomato", "onion", "garlic", "carrot", "broccoli", "pepper", "avocado", "lemon", "lime", "orange", "pear"]) {
            return .produce
        }
        if keyword(lower, in: ["milk", "yogurt", "cheese", "butter", "cream"]) {
            return .dairy
        }
        if keyword(lower, in: ["rice", "pasta", "noodle", "bread", "oat", "quinoa", "tortilla", "wrap"]) {
            return .grains
        }
        if keyword(lower, in: ["frozen"]) {
            return .frozen
        }
        if keyword(lower, in: ["oil", "vinegar", "salt", "pepper", "sauce", "soy sauce", "sriracha", "mustard", "ketchup", "mayo", "honey", "syrup"]) {
            return .condiments
        }
        if keyword(lower, in: ["chip", "cracker", "snack", "bar", "nut", "almond", "peanut"]) {
            return .snacks
        }
        if keyword(lower, in: ["water", "juice", "tea", "coffee", "soda", "drink"]) {
            return .beverages
        }
        if keyword(lower, in: ["flour", "sugar", "baking", "can", "beans", "lentil"]) {
            return .pantryStaple
        }
        return .other
    }

    private static func keyword(_ text: String, in words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }
}
