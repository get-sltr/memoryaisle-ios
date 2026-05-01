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

    /// PRIVACY INVARIANT: this history is in-memory only, scoped to the
    /// lifetime of this MiraConversation instance. Do NOT persist to
    /// SwiftData, UserDefaults, Keychain, or any cloud sink. The privacy
    /// policy (LEGAL-MemoryAisle.md §2.5/§2.7) commits that Mira
    /// conversations are not stored — that promise is held here and in
    /// MiraTabView.messages. If a future feature needs persistence (e.g.
    /// "save this Mira recipe"), copy the specific content into the
    /// existing SavedRecipe model rather than persisting the chat itself.
    ///
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
    ///
    /// `recentMeals` and `pantryItems` are optional name lists the caller
    /// can pass in so Mira can avoid repeating recent suggestions and
    /// favor things the user can actually make from what's on hand. Both
    /// default to empty for back-compat with non-chat call sites.
    func send(
        userText: String,
        context: MiraAPIClient.MiraContext?,
        recentMeals: [String] = [],
        pantryItems: [String] = []
    ) async throws -> String {
        // Prefix the user's text with a short situational hint so Mira picks
        // the right meal type for the time of day, doesn't repeat recent
        // meals, and prefers ingredients the user already has. The user
        // only sees their original text in the chat UI; this augmented
        // copy lives only in the API conversation history.
        let hint = Self.buildContextHint(
            recentMeals: recentMeals,
            pantryItems: pantryItems
        )
        let augmentedText = "[\(hint)]\n\n\(userText)"
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

    /// Builds the multi-line situational hint sent inside brackets at the
    /// top of every user turn. Always includes the current time + meal
    /// slot. Optionally includes recent meals (so Mira avoids repeats)
    /// and pantry items (so Mira can suggest things the user can actually
    /// make tonight). When both are empty Mira gets an explicit "this is
    /// a new user, vary your suggestions" instruction so brand-new users
    /// don't get the same default protein-rich shortlist every time.
    private static func buildContextHint(
        recentMeals: [String],
        pantryItems: [String]
    ) -> String {
        var lines: [String] = []

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
        lines.append("Current local time: \(timeString) (\(mealSlot))")

        if !recentMeals.isEmpty {
            let joined = recentMeals.prefix(10).joined(separator: ", ")
            lines.append("Recent meals (last 7 days): \(joined)")
        }

        if !pantryItems.isEmpty {
            let joined = pantryItems.prefix(20).joined(separator: ", ")
            lines.append("Pantry: \(joined)")
        }

        if recentMeals.isEmpty && pantryItems.isEmpty {
            lines.append("This user has no meal history or pantry items yet. Suggest a variety of options across cuisines (Asian, Mediterranean, American, Latin, etc.) and styles, not just the default protein-rich shortlist. Two or three different ideas with one quick \"what sounds good?\" follow-up.")
        } else {
            lines.append("Avoid repeating recent meals. Prefer pantry ingredients when relevant. Vary cuisine when suggesting.")
        }

        return lines.joined(separator: "\n")
    }
}
