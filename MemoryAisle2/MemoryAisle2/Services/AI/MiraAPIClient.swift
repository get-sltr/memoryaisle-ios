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
