import Foundation
import ImessageToNotesCore

/// The Summarizer: the Claude Messages API with a structured response.
/// Only the Transcript text leaves the Mac (ADR 0001).
final class ClaudeSummarizer: Summarizer {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let instructions = """
        You receive the Transcript of one Czech voice message that a person sent over iMessage. \
        The Transcript comes from speech recognition and can contain recognition errors.

        Write a summary in Czech: 2 to 4 sentences of plain prose that say what the speaker wants \
        the listener to know. Write about the speaker in the third person.

        Also list every action item in Czech: each task, date, deadline or request that the speaker \
        mentions, as one short line with the concrete details (who, what, when). If the message has \
        no action items, return an empty list. Do not invent details that the Transcript does not contain.
        """

    private static var schema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "summary": ["type": "string"],
                "action_items": ["type": "array", "items": ["type": "string"]],
            ],
            "required": ["summary", "action_items"],
            "additionalProperties": false,
        ]
    }

    private let model: String
    private let apiKey: String

    init(model: String, apiKey: String) {
        self.model = model
        self.apiKey = apiKey
    }

    func summarize(_ transcript: String) async throws -> Summary {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "max_tokens": 16_000,
            "fallbacks": "default",
            "system": Self.instructions,
            "messages": [["role": "user", "content": transcript]],
            "output_config": ["format": ["type": "json_schema", "schema": Self.schema]],
        ] as [String: Any])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard status == 200 else {
            let error = json["error"] as? [String: Any]
            throw AdapterError("Claude API returned HTTP \(status): \(error?["type"] ?? "") \(error?["message"] ?? "")")
        }

        let stopReason = json["stop_reason"] as? String
        guard stopReason == "end_turn" else {
            throw AdapterError("Claude API stopped with \(stopReason ?? "no stop reason")")
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw AdapterError("Claude API response has no text block")
        }
        let output = try JSONDecoder().decode(StructuredSummary.self, from: Data(text.utf8))
        return Summary(text: output.summary, actionItems: output.action_items)
    }

    private struct StructuredSummary: Decodable {
        var summary: String
        var action_items: [String]
    }
}
