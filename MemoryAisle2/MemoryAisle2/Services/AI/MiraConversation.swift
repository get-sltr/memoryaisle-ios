import Foundation
import SwiftData

/// Owns a single Mira chat conversation: maintains the message history in
/// Anthropic format, sends user turns to the API, runs the tool-use loop
/// against the local MiraToolExecutor, and returns the final text reply.
///
/// Lifetime is one chat session — create a new MiraConversation each time
/// the chat view appears, discard when it dismisses.
@MainActor
final class MiraConversation {
    private let client = MiraAPIClient()
    private let executor: MiraToolExecutor

    /// Conversation history in Anthropic messages format. Each entry is a
    /// dict with "role" ("user" or "assistant") and "content" (a string for
    /// simple text, or an array of content blocks for tool use / results).
    private var history: [[String: Any]] = []

    /// Hard cap on tool-call iterations per user turn to prevent runaway loops.
    private let maxToolIterations = 5

    init(executor: MiraToolExecutor) {
        self.executor = executor
    }

    /// Send a user message and return Mira's final text reply, executing any
    /// tool calls Claude makes along the way.
    func send(
        userText: String,
        context: MiraAPIClient.MiraContext?
    ) async throws -> String {
        // Prefix the user's text with a short time-of-day hint so Mira picks
        // the right meal type (breakfast vs. dinner vs. late-night snack)
        // when the user asks an open-ended "what should I eat" question.
        // The user only sees their original text in the chat UI; this
        // augmented copy lives only in the API conversation history.
        let augmentedText = "[\(Self.currentTimeHint())]\n\n\(userText)"
        history.append([
            "role": "user",
            "content": augmentedText
        ])

        var iterations = 0
        while iterations < maxToolIterations {
            iterations += 1

            let response = try await client.send(
                messages: history,
                context: context,
                useTools: true
            )

            // Always append Claude's assistant turn to history so that any
            // tool_use blocks are present when we send the tool_result back.
            if !response.assistantContent.isEmpty {
                history.append([
                    "role": "assistant",
                    "content": response.assistantContent
                ])
            }

            if response.toolUses.isEmpty {
                // No tools to run — return the text reply. If text is empty,
                // surface a fallback so the user isn't left staring at nothing.
                let trimmed = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty
                    ? "I worked on that but didn't have anything to add. Try asking again?"
                    : trimmed
            }

            // Execute each tool call and build a tool_result content array
            var toolResults: [[String: Any]] = []
            for toolUse in response.toolUses {
                let result = executor.execute(
                    toolName: toolUse.name,
                    input: toolUse.input
                )
                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": toolUse.id,
                    "content": result
                ])
            }

            // Append the tool results as a user-role message so Claude can
            // see them on the next turn
            history.append([
                "role": "user",
                "content": toolResults
            ])
        }

        return "I got stuck running tools for that one. Try rephrasing or breaking it into smaller steps?"
    }

    /// Reset the conversation history (used when starting a fresh chat).
    func reset() {
        history.removeAll()
    }

    /// Short, human-readable summary of the user's local time and the meal
    /// slot it implies. Mira uses this to avoid suggesting breakfast in the
    /// evening or dinner in the morning when the user asks an open-ended
    /// "what should I eat" question.
    private static func currentTimeHint() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let timeString = formatter.string(from: now)

        let hour = Calendar.current.component(.hour, from: now)
        let mealSlot: String
        switch hour {
        case 5..<10:  mealSlot = "morning, breakfast time"
        case 10..<14: mealSlot = "midday, lunch time"
        case 14..<17: mealSlot = "afternoon, snack time"
        case 17..<21: mealSlot = "evening, dinner time"
        default:      mealSlot = "late night, only a light snack is appropriate"
        }
        return "Current local time: \(timeString) (\(mealSlot))"
    }
}
