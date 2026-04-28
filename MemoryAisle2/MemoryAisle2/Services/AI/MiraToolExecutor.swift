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
        case "lookupDrugFact":
            return lookupDrugFact(input: input)
        case "getRecentSymptoms":
            return getRecentSymptoms()
        case "getMedicationPhaseSummary":
            return getMedicationPhaseSummary()
        case "lookupMedicationProgram":
            return lookupMedicationProgram(input: input)
        case "lookupAppealTemplate":
            return lookupAppealTemplate(input: input)
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

        // Each chat-logged meal gets its own NutritionLog row so the dashboard
        // and Reflection see meals as discrete events. Daily totals are
        // computed at read sites by summing today's rows.
        let log = NutritionLog(
            date: .now,
            proteinGrams: protein,
            caloriesConsumed: calories,
            waterLiters: 0,
            fiberGrams: fiber,
            foodName: name
        )
        context.insert(log)

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
        let todays = logs.filter { cal.isDateInToday($0.date) }
        guard !todays.isEmpty else {
            return "No meals logged yet today. Protein: 0g. Calories: 0. Water: 0L. Fiber: 0g."
        }
        let protein = todays.reduce(0) { $0 + $1.proteinGrams }
        let calories = todays.reduce(0) { $0 + $1.caloriesConsumed }
        let water = todays.reduce(0) { $0 + $1.waterLiters }
        let fiber = todays.reduce(0) { $0 + $1.fiberGrams }
        return "So far today, protein: \(Int(protein))g, calories: \(Int(calories)), water: \(String(format: "%.1f", water))L, fiber: \(Int(fiber))g."
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

    // MARK: - lookupDrugFact

    /// Returns a curated, FDA-grounded statement for the user's medication
    /// class and topic, or a deferral message when no curated entry exists.
    /// Mira is instructed to NEVER fabricate — the deferral is the safe path.
    private func lookupDrugFact(input: [String: Any]) -> String {
        guard let topicRaw = input["topic"] as? String,
              let topic = DrugFactTopic(rawValue: topicRaw) else {
            return "I need a topic to look up. Try one of: \(DrugFactTopic.allCases.map(\.rawValue).joined(separator: ", "))."
        }

        let descriptor = FetchDescriptor<UserProfile>()
        let profile = (try? context.fetch(descriptor))?.first
        let drugClass = DrugClass.from(medication: profile?.medication)

        if let fact = CuratedDrugFacts.lookup(drugClass: drugClass, topic: topic) {
            return "\(fact.statement) (Source: \(fact.sourceURL.absoluteString); reviewed \(formatDate(fact.reviewedAt)).)"
        }

        return "I don't have a verified number for \(topic.rawValue) on this medication class. The FDA package insert is the safer source — your prescriber can also walk you through it."
    }

    // MARK: - getRecentSymptoms

    /// Returns an anonymized 7-day symptom summary for side-effect triage.
    /// Numbers stay coarse on purpose so Mira reasons in tendencies, not
    /// false-precision vitals.
    private func getRecentSymptoms() -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<SymptomLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let logs = (try? context.fetch(descriptor)) ?? []
        let recent = logs.filter { $0.date >= cutoff }

        guard !recent.isEmpty else {
            return "No symptoms logged in the past 7 days."
        }

        let avgNausea = Double(recent.reduce(0) { $0 + $1.nauseaLevel }) / Double(recent.count)
        let avgAppetite = Double(recent.reduce(0) { $0 + $1.appetiteLevel }) / Double(recent.count)
        let avgEnergy = Double(recent.reduce(0) { $0 + $1.energyLevel }) / Double(recent.count)

        let nauseaBand = symptomBand(value: avgNausea, lowLabel: "minimal", midLabel: "mild", highLabel: "moderate to severe")
        let appetiteBand = symptomBand(value: avgAppetite, lowLabel: "very low", midLabel: "low", highLabel: "near normal")
        let energyBand = symptomBand(value: avgEnergy, lowLabel: "low", midLabel: "fair", highLabel: "good")

        return "Past 7 days, \(recent.count) entries. Nausea: \(nauseaBand). Appetite: \(appetiteBand). Energy: \(energyBand)."
    }

    private func symptomBand(value: Double, lowLabel: String, midLabel: String, highLabel: String) -> String {
        switch value {
        case 0..<1.5: return lowLabel
        case 1.5..<3: return midLabel
        default:      return highLabel
        }
    }

    // MARK: - getMedicationPhaseSummary

    /// Cycle phase + days-since-injection + appetite hint so Mira can be
    /// cycle-aware in conversation. Pulls from the active MedicationProfile
    /// when present; otherwise returns a clean "no medication on file" so
    /// the model doesn't invent context.
    private func getMedicationPhaseSummary() -> String {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? context.fetch(descriptor))?.first else {
            return "No user profile yet."
        }

        guard let injectionDay = profile.injectionDay else {
            return "User isn't on an injection schedule (oral or no medication on file)."
        }

        let daysSince = InjectionCycleEngine.daysSince(injectionDay: injectionDay)
        let phase = InjectionCycleEngine.currentPhase(injectionDay: injectionDay)
        let appetite = phase.appetiteDescription

        return "Cycle phase: \(phase.rawValue) (day \(daysSince) of 7). Strategy: \(phase.proteinStrategy). Appetite expected: \(appetite)."
    }

    // MARK: - lookupMedicationProgram (assistance role, scaffold only)

    /// Manufacturer programs / patient assistance lookup. Ships intentionally
    /// empty — entries land after legal sign-off on the curated dataset.
    /// Until then, returns a deferral that points the user at general
    /// manufacturer support without inventing program names or savings.
    private func lookupMedicationProgram(input: [String: Any]) -> String {
        let drugHint = input["drugClass"] as? String ?? "this medication"
        return "I don't have a curated assistance-program list for \(drugHint) yet. The manufacturer's support line on the box is the safest first call. We're working on adding verified program details."
    }

    // MARK: - lookupAppealTemplate (assistance role, scaffold only)

    /// Insurance appeal-letter template lookup. Ships intentionally empty —
    /// templates land after legal sign-off on language. Returns a deferral
    /// that names what categories will eventually be available.
    private func lookupAppealTemplate(input: [String: Any]) -> String {
        let category = input["category"] as? String ?? "general"
        return "I don't have a verified appeal template for the '\(category)' category yet. When it's ready, you'll find it here. For now, your prescriber's office often has appeal language on file."
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

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
