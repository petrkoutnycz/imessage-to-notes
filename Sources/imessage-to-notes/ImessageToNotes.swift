import AVFoundation
import Foundation
import ImessageToNotesCore

/// The tool's files on this Mac.
enum Paths {
    static let support = URL.applicationSupportDirectory.appending(path: "imessage-to-notes")
    static let configuration = support.appending(path: "config.json")
    static let stateStore = support.appending(path: "state.sqlite")
    static let models = support.appending(path: "models")
    static let messagesDatabase = URL.homeDirectory.appending(path: "Library/Messages/chat.db")
}

@main
struct ImessageToNotes {
    static func main() async {
        let command = CommandLine.arguments.dropFirst().first ?? "run"
        do {
            switch command {
            case "run":
                try await run()
            case "probe":
                try await probe()
            case "sample" where CommandLine.arguments.count == 3:
                try await sample(audioPath: CommandLine.arguments[2])
            default:
                print("usage: imessage-to-notes [run | probe | sample <audio file>]")
                exit(64)
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    /// Turns the newest Voice Message from a Tracked Contact into a Message Note.
    @MainActor
    static func run() async throws {
        let configuration = try Configuration.load(from: Paths.configuration)
        let adapters = Adapters(
            messages: try MessagesDatabaseReader(path: Paths.messagesDatabase.path),
            transcriber: WhisperKitTranscriber(modelsDirectory: Paths.models),
            summarizer: ClaudeSummarizer(model: configuration.claudeModel, apiKey: try Keychain.anthropicAPIKey()),
            notes: AppleScriptNotesWriter(),
            state: try SQLiteStateStore(path: Paths.stateStore.path),
            clock: SystemClock()
        )
        switch try await runOnce(configuration: configuration, adapters: adapters) {
        case .noVoiceMessage:
            print("No Voice Message from a Tracked Contact.")
        case .alreadyDone(let guid):
            print("Voice Message \(guid) is already done. No new Message Note.")
        case .created(let guid, let noteID):
            print("Voice Message \(guid) became Message Note \(noteID).")
        }
    }

    /// Runs the real Transcriber and Summarizer on one audio file and prints the results.
    /// It writes nothing to disk except the Whisper model.
    @MainActor
    static func sample(audioPath: String) async throws {
        let transcript = try await WhisperKitTranscriber(modelsDirectory: Paths.models).transcribe(audioAt: audioPath)
        print("Transcript:\n\(transcript)\n")
        let configuration = try Configuration.load(from: Paths.configuration)
        let summarizer = ClaudeSummarizer(model: configuration.claudeModel, apiKey: try Keychain.anthropicAPIKey())
        let summary = try await summarizer.summarize(transcript)
        print("Summary:\n\(summary.text)\n")
        print("Action Items:" + (summary.actionItems.isEmpty ? " none" : ""))
        summary.actionItems.forEach { print("- \($0)") }
    }

    /// Prints how the real Messages database, audio files and Notes accounts match what the spec expects.
    @MainActor
    static func probe() async throws {
        let configuration = try Configuration.load(from: Paths.configuration)
        print("Messages database: \(Paths.messagesDatabase.path)")
        let probe = try MessagesDatabaseProbe(path: Paths.messagesDatabase.path)
        let report = try probe.report(handles: configuration.handles)
        report.lines.forEach { print($0) }

        if let newest = report.audioAttachments.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            do {
                let file = try AVAudioFile(forReading: URL(filePath: newest.path))
                let format = file.fileFormat
                let seconds = Double(file.length) / format.sampleRate
                // Decode the whole file into PCM, as the Transcriber does.
                guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                    throw AdapterError("Cannot allocate an audio buffer")
                }
                try file.read(into: buffer)
                print("audio \(newest.guid) decodes: \(format.settings[AVFormatIDKey] ?? "?") format ID, "
                    + "\(format.sampleRate) Hz, \(format.channelCount) channel(s), \(String(format: "%.1f", seconds)) s, "
                    + "\(buffer.frameLength) frames decoded")
            } catch {
                print("audio \(newest.guid) does NOT decode: \(error)")
            }
        }

        let accounts = try AppleScript.run("tell application \"Notes\" to get name of every account")
        let names = (0..<accounts.numberOfItems).compactMap { accounts.atIndex($0 + 1)?.stringValue }
        print("Notes accounts: \(names)")
        let folderExists = try AppleScript.run("""
            tell application "Notes" to exists folder \(AppleScript.literal(configuration.notesFolder)) \
            of account \(AppleScript.literal(AppleScriptNotesWriter.accountName))
            """)
        print("Notes Folder \"\(configuration.notesFolder)\" in account \(AppleScriptNotesWriter.accountName): "
            + (folderExists.booleanValue ? "exists" : "MISSING"))
    }
}
