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
