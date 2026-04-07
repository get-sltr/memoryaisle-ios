import Foundation

struct MiraAPIClient: Sendable {
    private let endpoint = "https://9n2u3mkkma.execute-api.us-east-1.amazonaws.com/prod/mira"

    struct MiraContext: Codable, Sendable {
        let medication: String?
        let mode: String?
        let proteinTarget: Int?
        let proteinToday: Int?
        let waterToday: Double?
        let trainingLevel: String?
        let nauseaLevel: String?
    }

    struct MiraRequest: Codable, Sendable {
        let message: String
        let context: MiraContext?
    }

    struct MiraResponse: Codable, Sendable {
        let reply: String?
        let error: String?
    }

    func send(message: String, context: MiraContext?) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw MiraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = MiraRequest(message: message, context: context)
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
