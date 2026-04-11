import Foundation

/// Client for the miraSpeak Lambda endpoint.
/// Calls Amazon Polly Generative TTS and returns MP3 audio data.
struct MiraTTSClient: Sendable {
    private let endpoint = "https://9n2u3mkkma.execute-api.us-east-1.amazonaws.com/prod/mira/speak"

    private struct TTSRequest: Codable, Sendable {
        let text: String
    }

    private struct TTSResponse: Codable, Sendable {
        let audio: String?
        let format: String?
        let voice: String?
        let error: String?
    }

    /// Synthesizes the given text into MP3 audio data via Polly.
    /// Throws on any network, server, or decoding error so the caller
    /// can fall back to on-device TTS.
    func synthesize(text: String) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw TTSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = TTSRequest(text: text)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw TTSError.serverError(httpResponse.statusCode)
        }

        let ttsResponse = try JSONDecoder().decode(TTSResponse.self, from: data)

        if let error = ttsResponse.error {
            throw TTSError.apiError(error)
        }

        guard let audioBase64 = ttsResponse.audio,
              let audioData = Data(base64Encoded: audioBase64) else {
            throw TTSError.decodingError
        }

        return audioData
    }
}

enum TTSError: LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case apiError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid TTS endpoint"
        case .networkError: "Network connection failed"
        case .serverError(let code): "Server error (\(code))"
        case .apiError(let msg): msg
        case .decodingError: "Could not decode audio response"
        }
    }
}
