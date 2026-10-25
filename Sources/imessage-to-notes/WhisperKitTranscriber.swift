import Foundation
import ImessageToNotesCore
import WhisperKit

/// The Transcriber: Whisper large-v3 on this Mac, language fixed to Czech.
final class WhisperKitTranscriber: Transcriber {
    static let model = "openai_whisper-large-v3"

    private let modelsDirectory: URL

    init(modelsDirectory: URL) {
        self.modelsDirectory = modelsDirectory
    }

    func transcribe(audioAt path: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AdapterError("The audio file is missing: \(path)")
        }
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let whisper = try await WhisperKit(WhisperKitConfig(
            model: Self.model,
            downloadBase: modelsDirectory,
            verbose: false
        ))
        let options = DecodingOptions(
            task: .transcribe,
            language: "cs",
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await whisper.transcribe(audioPath: path, decodeOptions: options)
        let transcript = results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw AdapterError("Whisper returned an empty Transcript")
        }
        return transcript
    }
}
