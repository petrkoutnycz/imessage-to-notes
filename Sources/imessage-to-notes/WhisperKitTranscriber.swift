import AVFoundation
import Foundation
import ImessageToNotesCore
import WhisperKit

/// The Transcriber: Whisper large-v3 on this Mac, language fixed to Czech.
final class WhisperKitTranscriber: Transcriber {
    static let model = "openai_whisper-large-v3"

    private let downloadBase: URL

    /// The Hugging Face Hub library adds `models/<owner>/<repository>` under `downloadBase`.
    init(downloadBase: URL) {
        self.downloadBase = downloadBase
    }

    func transcribe(audioAt path: String) async throws -> TranscribedAudio {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AdapterError("The audio file is missing: \(path)")
        }
        let audioFile = try AVAudioFile(forReading: URL(filePath: path))
        let audioDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        try FileManager.default.createDirectory(at: downloadBase, withIntermediateDirectories: true)
        let whisper = try await WhisperKit(WhisperKitConfig(
            model: Self.model,
            downloadBase: downloadBase,
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
        return TranscribedAudio(transcript: transcript, audioDuration: audioDuration)
    }
}
