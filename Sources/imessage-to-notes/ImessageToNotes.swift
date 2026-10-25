import AVFoundation
import Foundation
import ImessageToNotesCore

/// The tool's files on this Mac.
enum Paths {
    static let support = URL.applicationSupportDirectory.appending(path: "imessage-to-notes")
    static let configuration = support.appending(path: "config.json")
    static let stateStore = support.appending(path: "state.sqlite")
    static let runLock = support.appending(path: "run.lock")
    static let logs = URL.libraryDirectory.appending(path: "Logs/imessage-to-notes")
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

    /// Turns every Voice Message from a Tracked Contact that is not done into a Message Note.
    @MainActor
    static func run() async throws {
        let log = FileLog(directory: Paths.logs)
        let configuration: Configuration
        let adapters: Adapters
        do {
            configuration = try Configuration.load(from: Paths.configuration)
            adapters = Adapters(
                messages: try MessagesDatabaseReader(path: Paths.messagesDatabase.path),
                transcriber: WhisperKitTranscriber(downloadBase: Paths.support),
                summarizer: ClaudeSummarizer(model: configuration.claudeModel, apiKey: try Keychain.anthropicAPIKey()),
                notes: AppleScriptNotesWriter(),
                state: try SQLiteStateStore(path: Paths.stateStore.path),
                clock: SystemClock(),
                lock: FileRunLock(path: Paths.runLock.path),
                log: log
            )
        } catch {
            // launchd keeps no output of a background run, so the log is the only record of this failure.
            try? log.write(LogEntry(time: Date(), event: .runFailed(error: String(describing: error))))
            throw error
        }
        let report = try await runOnce(configuration: configuration, adapters: adapters)
        if report.lockHeldByAnotherRun {
            print("Another run is active. This run does nothing.")
            return
        }
        print("Voice Messages already done: \(report.alreadyDone.count).")
        for created in report.created {
            print("Voice Message \(created.guid) became Message Note \(created.noteID).")
        }
        if report.created.isEmpty {
            print("No new Message Note.")
        }
    }

    /// Runs the real Transcriber and Summarizer on one audio file and prints the results.
    /// It writes nothing to disk except the Whisper model.
    @MainActor
    static func sample(audioPath: String) async throws {
        let transcript = try await WhisperKitTranscriber(downloadBase: Paths.support).transcribe(audioAt: audioPath).transcript
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
