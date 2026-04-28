import Foundation

/// Describes a tool that Mira (Claude) can call on the iOS client.
/// The name and input_schema here must match exactly what the Lambda's
/// TOOLS array declares, because Claude's tool-use response will reference
/// these names when it decides to call one.
struct MiraTool: Codable, Sendable {
    let name: String
    let description: String
    let inputSchema: InputSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }

    struct InputSchema: Codable, Sendable {
        let type: String
        let properties: [String: PropertySchema]?
        let required: [String]?
    }

    struct PropertySchema: Codable, Sendable {
        let type: String
        let description: String?
        let items: ItemSchema?
    }

    struct ItemSchema: Codable, Sendable {
        let type: String
    }
}

enum MiraToolRegistry {
    /// The canonical list of tools Mira has access to. Keep in sync with
    /// the TOOLS array in Infrastructure/lambda/miraGenerate/index.mjs —
    /// both sides need identical names and schemas for tool calls to work.
    static let all: [MiraTool] = [
        MiraTool(
            name: "addToGroceryList",
            description: "Add items to the user's on-device grocery list. Use when the user asks to add items, export a recipe's ingredients, or save a shopping list.",
            inputSchema: .init(
                type: "object",
                properties: [
                    "items": .init(
                        type: "array",
                        description: "Short, shopper-friendly item names. No quantities.",
                        items: .init(type: "string")
                    )
                ],
                required: ["items"]
            )
        ),
        MiraTool(
            name: "logMeal",
            description: "Log a meal the user just ate, adding its nutrition to today's totals.",
            inputSchema: .init(
                type: "object",
                properties: [
                    "name": .init(type: "string", description: "Short meal name.", items: nil),
                    "proteinGrams": .init(type: "number", description: "Estimated grams of protein.", items: nil),
                    "calories": .init(type: "number", description: "Estimated calories.", items: nil),
                    "fiberGrams": .init(type: "number", description: "Estimated grams of fiber. 0 if unknown.", items: nil)
                ],
                required: ["name", "proteinGrams", "calories"]
            )
        ),
        MiraTool(
            name: "getTodayNutrition",
            description: "Fetch the user's nutrition totals for today (protein, calories, water, fiber).",
            inputSchema: .init(type: "object", properties: [:], required: [])
        ),
        MiraTool(
            name: "getUserTargets",
            description: "Fetch the user's daily targets and weight goal.",
            inputSchema: .init(type: "object", properties: [:], required: [])
        ),
        MiraTool(
            name: "lookupDrugFact",
            description: "Look up a curated, FDA-PI-grounded fact about the user's medication class. Use this whenever you would otherwise quote a specific drug number (side-effect prevalence, half-life, dosing schedule, contraindications, warnings, interactions, renal/hepatic adjustments). Returns 'no curated data' for topics that haven't been reviewed yet — say so honestly rather than invent.",
            inputSchema: .init(
                type: "object",
                properties: [
                    "topic": .init(
                        type: "string",
                        description: "One of: sideEffectPrevalence, halfLife, dosingSchedule, contraindications, warnings, interactions, adjustmentForRenalImpairment, adjustmentForHepaticImpairment, other.",
                        items: nil
                    )
                ],
                required: ["topic"]
            )
        ),
        MiraTool(
            name: "getRecentSymptoms",
            description: "Fetch an anonymized 7-day summary of the user's logged symptoms (nausea, appetite, energy bands). Use this for side-effect triage to ground 'what to do today' advice in the user's actual recent state.",
            inputSchema: .init(type: "object", properties: [:], required: [])
        ),
        MiraTool(
            name: "getMedicationPhaseSummary",
            description: "Fetch the user's current cycle phase, days-since-injection, and expected appetite description. Use this to be cycle-aware in conversation without restating profile.",
            inputSchema: .init(type: "object", properties: [:], required: [])
        ),
        MiraTool(
            name: "lookupMedicationProgram",
            description: "Look up curated manufacturer assistance programs for a drug class (NovoCare, Lilly Cares, etc.). Currently returns a deferral until the curated dataset has legal sign-off — never invent program names or savings.",
            inputSchema: .init(
                type: "object",
                properties: [
                    "drugClass": .init(type: "string", description: "Anonymized drug class (semaglutide, tirzepatide, orforglipron, unknown).", items: nil)
                ],
                required: []
            )
        ),
        MiraTool(
            name: "lookupAppealTemplate",
            description: "Look up a curated insurance-appeal letter template by category (e.g., 'medical_necessity', 'step_therapy_override'). Currently returns a deferral until the curated dataset has legal sign-off.",
            inputSchema: .init(
                type: "object",
                properties: [
                    "category": .init(type: "string", description: "Appeal category. Optional.", items: nil)
                ],
                required: []
            )
        )
    ]
}
