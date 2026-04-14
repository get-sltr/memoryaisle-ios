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
        )
    ]
}
