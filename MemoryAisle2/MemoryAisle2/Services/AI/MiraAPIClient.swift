import Foundation
import UIKit

struct MiraAPIClient: Sendable {
    private let endpoint = "https://9n2u3mkkma.execute-api.us-east-1.amazonaws.com/prod/mira"

    struct MiraContext: Codable, Sendable {
        let medicationClass: String?
        let doseTier: String?
        let daysSinceDose: Int?
        let phase: String?
        let symptomState: String?
        let mode: String?
        let proteinTarget: Int?
        let proteinToday: Int?
        let waterToday: Double?
        let trainingLevel: String?
        let trainingToday: Bool?
        let calorieTarget: Int?
        let dietaryRestrictions: [String]?
    }

    struct MiraRequest: Codable, Sendable {
        let message: String
        let context: MiraContext?
        let imageBase64: String?
        let imageMediaType: String?
    }

    struct MiraResponse: Codable, Sendable {
        let reply: String?
        let error: String?
    }

    /// A single tool call requested by Claude in a tool-use response.
    struct ToolUse: Sendable {
        let id: String
        let name: String
        let input: [String: Any]
    }

    /// The result of a tool-use-aware send. May contain pure text, may contain
    /// tool_use blocks that the caller must execute and continue with, or both.
    struct ToolAwareResponse: Sendable {
        /// Text content from the assistant. May be empty when stopReason is "tool_use".
        let text: String
        /// The full assistant content blocks, kept verbatim so the caller can echo
        /// them back as the assistant turn in the next request's messages array.
        let assistantContent: [[String: Any]]
        /// Tool calls Claude wants the client to execute.
        let toolUses: [ToolUse]
        /// Bedrock stop reason: "end_turn", "tool_use", "max_tokens", etc.
        let stopReason: String?
    }

    func send(message: String, context: MiraContext?) async throws -> String {
        try await send(message: message, context: context, imageData: nil)
    }

    func send(
        message: String,
        context: MiraContext?,
        imageData: Data?
    ) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw MiraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var encodedImage: String?
        if let imageData {
            encodedImage = await MainActor.run { Self.prepareImage(imageData) }
        }

        let body = MiraRequest(
            message: message,
            context: context,
            imageBase64: encodedImage,
            imageMediaType: encodedImage != nil ? "image/jpeg" : nil
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiraError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw MiraError.serverError(httpResponse.statusCode)
        }

        let miraResponse = try JSONDecoder().decode(MiraResponse.self, from: data)

        if let error = miraResponse.error {
            throw MiraError.apiError(error)
        }

        return miraResponse.reply ?? "I'm having a moment. Try again?"
    }

    /// Tool-use-aware send. Takes the full conversation messages array (in
    /// Anthropic's format — each message is a dict with "role" and "content")
    /// and returns either pure text or a list of tool calls Claude wants the
    /// client to execute. The caller is responsible for the loop.
    func send(
        messages: [[String: Any]],
        context: MiraContext?,
        useTools: Bool
    ) async throws -> ToolAwareResponse {
        guard let url = URL(string: endpoint) else {
            throw MiraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body: [String: Any] = [
            "messages": messages,
            "useTools": useTools
        ]
        if let context {
            body["context"] = encodeContextDict(context)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiraError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw MiraError.serverError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MiraError.networkError
        }

        if let errorMsg = json["error"] as? String {
            throw MiraError.apiError(errorMsg)
        }

        let text = (json["reply"] as? String) ?? ""
        let stopReason = json["stopReason"] as? String
        let assistantContent = (json["assistantContent"] as? [[String: Any]]) ?? []

        var toolUses: [ToolUse] = []
        if let rawUses = json["toolUses"] as? [[String: Any]] {
            for raw in rawUses {
                guard let id = raw["id"] as? String,
                      let name = raw["name"] as? String,
                      let input = raw["input"] as? [String: Any]
                else { continue }
                toolUses.append(ToolUse(id: id, name: name, input: input))
            }
        }

        return ToolAwareResponse(
            text: text,
            assistantContent: assistantContent,
            toolUses: toolUses,
            stopReason: stopReason
        )
    }

    // MARK: - Proactive meal recommendations (structured output)

    /// Decoded shape of the Lambda's `mode: "recommend"` response. The
    /// Lambda forces Claude to call a `presentMealRecommendations` tool
    /// with this exact schema, so the field set here matches the tool's
    /// input_schema in `Infrastructure/lambda/miraGenerate/index.mjs`.
    private struct RecommendResponse: Decodable {
        let recommendations: [RecommendedMeal]?
        let error: String?
    }

    private struct RecommendedMeal: Decodable {
        let name: String
        let calories: Int
        let proteinG: Int
        let fatG: Int
        let carbsG: Int
        let reasoning: String
        let ingredients: [String]
        let isDoseDayFriendly: Bool
    }

    /// Asks Bedrock for 3 proactive meal recommendations tuned to the user's
    /// current state. Returns exactly 3 meals on success (the server-side
    /// tool schema enforces minItems=maxItems=3) or throws on transport,
    /// parse, or server-reported failure.
    func recommendMeals(
        context: MiraContext?,
        mealWindow: String,
        recentMeals: [String],
        pantryItems: [String]
    ) async throws -> [MealRecommendation] {
        guard let url = URL(string: endpoint) else {
            throw MiraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body: [String: Any] = [
            "mode": "recommend",
            "mealWindow": mealWindow,
        ]
        if !recentMeals.isEmpty { body["recentMeals"] = recentMeals }
        if !pantryItems.isEmpty { body["pantryItems"] = pantryItems }
        if let context { body["context"] = encodeContextDict(context) }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiraError.networkError
        }
        guard httpResponse.statusCode == 200 else {
            throw MiraError.serverError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(RecommendResponse.self, from: data)
        if let err = decoded.error {
            throw MiraError.apiError(err)
        }
        guard let raw = decoded.recommendations, raw.count >= 1 else {
            throw MiraError.apiError("No recommendations returned")
        }
        return raw.map { meal in
            MealRecommendation(
                name: meal.name,
                calories: meal.calories,
                proteinG: meal.proteinG,
                fatG: meal.fatG,
                carbsG: meal.carbsG,
                reasoning: meal.reasoning,
                ingredients: meal.ingredients,
                isDoseDayFriendly: meal.isDoseDayFriendly
            )
        }
    }

    // MARK: - Meal-plan structured generation (one day at a time)

    /// Decoded shape of the Lambda's `mode: "meal_plan"` response. Mirrors
    /// the `presentMealPlan` tool input_schema in
    /// `Infrastructure/lambda/miraGenerate/meal-plan-schema.mjs` exactly.
    /// Field names use snake_case to match the Bedrock tool contract; the
    /// SwiftData model conversion happens in MealGenerator.
    struct MealPlanDayPayload: Decodable, Sendable {
        let meals: [MealPlanMealPayload]
    }

    struct MealPlanMealPayload: Decodable, Sendable {
        let type: String
        let name: String
        let protein_g: Double
        let calories: Double
        let carbs_g: Double
        let fat_g: Double
        let fiber_g: Double
        let prep_minutes: Int
        let nausea_safe: Bool
        let ingredients: [String]
        let cooking_instructions: [String]
    }

    /// Why the Lambda rejected a meal-plan call. Drives MealGenerator's
    /// retry classification: 5xx + transport errors get the existing
    /// exponential backoff (3 attempts); schemaValidation gets one retry
    /// max because retrying a schema failure usually wastes spend on the
    /// same broken state.
    enum MealPlanError: Error, Sendable {
        case schemaValidation(details: [String])
        case noToolUseBlock
        case server(status: Int, message: String)
        case transport(Error)
        case decode(Error)

        var isRetryable: Bool {
            switch self {
            case .schemaValidation: return false
            case .noToolUseBlock:   return true
            case .server(let status, _): return status >= 500
            case .transport:        return true
            case .decode:           return false
            }
        }
    }

    /// Asks Bedrock for ONE day of meals. Routes via `mode: "meal_plan"` —
    /// no substring match on the user message — so a copy-edit on the
    /// client prompt template can't silently break the short-circuit.
    /// Throws `MealPlanError`; caller (MealGenerator) classifies retry.
    func generateMealPlan(
        context: MiraContext?,
        cyclePhase: String?,
        isTrainingDay: Bool,
        avoidMealNames: [String],
        pantryItems: [String]
    ) async throws -> [MealPlanMealPayload] {
        guard let url = URL(string: endpoint) else {
            throw MealPlanError.server(status: 0, message: "Invalid endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body: [String: Any] = [
            "mode": "meal_plan",
            "isTrainingDay": isTrainingDay
        ]
        if let cyclePhase, !cyclePhase.isEmpty { body["cyclePhase"] = cyclePhase }
        if !avoidMealNames.isEmpty { body["avoidMealNames"] = avoidMealNames }
        if !pantryItems.isEmpty { body["pantryItems"] = pantryItems }
        if let context { body["context"] = encodeContextDict(context) }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MealPlanError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw MealPlanError.server(status: 0, message: "No HTTP response")
        }

        if http.statusCode == 422 {
            // Schema validation failure — Lambda rejected the model's
            // tool input. Surface details so MealGenerator can log and
            // decide retry policy.
            let detail = decodeErrorDetails(data: data)
            throw MealPlanError.schemaValidation(details: detail.details)
        }

        if http.statusCode == 502 {
            // No tool_use block came back — model refused or hit max
            // tokens. Retryable per MealPlanError.isRetryable.
            throw MealPlanError.noToolUseBlock
        }

        guard http.statusCode == 200 else {
            let detail = decodeErrorDetails(data: data)
            throw MealPlanError.server(status: http.statusCode, message: detail.message)
        }

        do {
            let decoded = try JSONDecoder().decode(MealPlanDayPayload.self, from: data)
            return decoded.meals
        } catch {
            throw MealPlanError.decode(error)
        }
    }

    private func decodeErrorDetails(data: Data) -> (message: String, details: [String]) {
        struct ErrorEnvelope: Decodable {
            let error: String?
            let kind: String?
            let details: [String]?
        }
        guard let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) else {
            return ("Unknown error", [])
        }
        return (env.error ?? "Unknown error", env.details ?? [])
    }

    /// Convert MiraContext to a JSON-serializable dictionary. We can't use
    /// JSONEncoder with [String: Any] mixing, so we hand-build the dict.
    private func encodeContextDict(_ ctx: MiraContext) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let v = ctx.medicationClass { dict["medicationClass"] = v }
        if let v = ctx.doseTier { dict["doseTier"] = v }
        if let v = ctx.daysSinceDose { dict["daysSinceDose"] = v }
        if let v = ctx.phase { dict["phase"] = v }
        if let v = ctx.symptomState { dict["symptomState"] = v }
        if let v = ctx.mode { dict["mode"] = v }
        if let v = ctx.proteinTarget { dict["proteinTarget"] = v }
        if let v = ctx.proteinToday { dict["proteinToday"] = v }
        if let v = ctx.waterToday { dict["waterToday"] = v }
        if let v = ctx.trainingLevel { dict["trainingLevel"] = v }
        if let v = ctx.trainingToday { dict["trainingToday"] = v }
        if let v = ctx.calorieTarget { dict["calorieTarget"] = v }
        if let v = ctx.dietaryRestrictions { dict["dietaryRestrictions"] = v }
        return dict
    }

    @MainActor
    private static func prepareImage(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }

        let maxDimension: CGFloat = 1024
        let scale = min(
            maxDimension / max(image.size.width, 1),
            maxDimension / max(image.size.height, 1),
            1.0
        )

        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.jpegData(withCompressionQuality: 0.7) { ctx in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.base64EncodedString()
    }
}

enum MiraError: LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid API endpoint"
        case .networkError: "Network connection failed"
        case .serverError(let code): "Server error (\(code))"
        case .apiError(let msg): msg
        }
    }
}
