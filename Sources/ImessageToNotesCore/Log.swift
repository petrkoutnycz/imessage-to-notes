import Foundation

/// One entry of the run log.
public struct LogEntry: Equatable, Sendable {
    public var time: Date
    public var event: LogEvent

    public init(time: Date, event: LogEvent) {
        self.time = time
        self.event = event
    }
}

public enum LogEvent: Equatable, Sendable {
    case runStarted
    /// Another run held the run lock, so this run did nothing.
    case runSkipped
    /// `pending` counts the Voice Messages with a failed step that a later run tries again.
    case runFinished(created: Int, alreadyDone: Int, pending: Int)
    /// A failure outside the steps of one Voice Message, for example in the Messages Reader.
    case runFailed(error: String)
    /// The run could not delete old log files. The run goes on.
    case logCleanupFailed(error: String)
    /// The iCloud account has no Notes Folder, so the run stopped before any Voice Message.
    case notesFolderMissing(notesFolder: String)
    /// The Notifier sent the notification about the missing Notes Folder.
    case notesFolderNotified
    /// The Notifier could not send the notification about the missing Notes Folder. The next run tries again.
    case notesFolderNotificationFailed(error: String)
    case voiceMessage(VoiceMessageLogEntry)
    /// A click on a notification did not open its Message Note.
    case messageNoteOpenFailed(noteID: String, error: String)
    /// A click on the notification about a missing Notes Folder did not open Notes.
    case notesOpenFailed(error: String)
}

/// What happened to one Voice Message in one step.
public struct VoiceMessageLogEntry: Equatable, Sendable {
    public var guid: String
    public var trackedContactName: String
    public var sentAt: Date
    /// The length of the audio in seconds, known after transcription.
    public var audioDuration: TimeInterval?
    public var status: VoiceMessageStepStatus

    public init(
        guid: String,
        trackedContactName: String,
        sentAt: Date,
        audioDuration: TimeInterval? = nil,
        status: VoiceMessageStepStatus
    ) {
        self.guid = guid
        self.trackedContactName = trackedContactName
        self.sentAt = sentAt
        self.audioDuration = audioDuration
        self.status = status
    }
}

public enum VoiceMessageStep: String, Sendable {
    case transcribe
    case summarize
    case createMessageNote = "create-message-note"
    case notify
}

public enum VoiceMessageStepStatus: Equatable, Sendable {
    case alreadyDone
    case transcribed
    case summarized
    case done(noteID: String)
    /// A step failed for the whole retry window, and the run created a fallback Message Note.
    case fallback(noteID: String)
    /// The Notifier sent the notification about the Message Note.
    case notified(noteID: String)
    /// `error` holds no Transcript or Summary text.
    case failed(step: VoiceMessageStep, error: String)
}

extension LogEntry {
    /// The entry as one line of text, with times in `timeZone`.
    public func line(timeZone: TimeZone) -> String {
        let timestamp = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone)
        var fields = [time.formatted(timestamp)]
        switch event {
        case .runStarted:
            fields.append("run started")
        case .runSkipped:
            fields.append("run skipped: another run is active")
        case .runFinished(let created, let alreadyDone, let pending):
            fields += ["run finished", "created=\(created)", "already-done=\(alreadyDone)", "pending=\(pending)"]
        case .runFailed(let error):
            fields += ["run failed", "error=\(quoted(error))"]
        case .logCleanupFailed(let error):
            fields += ["log cleanup failed", "error=\(quoted(error))"]
        case .notesFolderMissing(let notesFolder):
            fields += ["run stopped: notes folder missing", "notes-folder=\(quoted(notesFolder))"]
        case .notesFolderNotified:
            fields.append("notes folder notification sent")
        case .notesFolderNotificationFailed(let error):
            fields += ["notes folder notification failed", "error=\(quoted(error))"]
        case .messageNoteOpenFailed(let noteID, let error):
            fields += ["message note open failed", "note=\(noteID)", "error=\(quoted(error))"]
        case .notesOpenFailed(let error):
            fields += ["notes open failed", "error=\(quoted(error))"]
        case .voiceMessage(let entry):
            fields += [
                "voice-message",
                "guid=\(entry.guid)",
                "tracked-contact=\(quoted(entry.trackedContactName))",
                "sent=\(entry.sentAt.formatted(timestamp))",
            ]
            if let audioDuration = entry.audioDuration {
                fields.append("duration=\(String(format: "%.1f", audioDuration))s")
            }
            switch entry.status {
            case .alreadyDone:
                fields.append("status=already-done")
            case .transcribed:
                fields.append("status=transcribed")
            case .summarized:
                fields.append("status=summarized")
            case .done(let noteID):
                fields += ["status=done", "note=\(noteID)"]
            case .fallback(let noteID):
                fields += ["status=fallback", "note=\(noteID)"]
            case .notified(let noteID):
                fields += ["status=notified", "note=\(noteID)"]
            case .failed(let step, let error):
                fields += ["status=failed", "step=\(step.rawValue)", "error=\(quoted(error))"]
            }
        }
        return fields.joined(separator: " ")
    }

    /// A value in double quotes on one line.
    private func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

/// Keeps private text out of the log.
enum PrivateText {
    /// The shortest run of characters that counts as a quote of private text.
    static let minimumQuoteLength = 10

    /// `text` with "[redacted]" in place of each run of at least `minimumQuoteLength` characters
    /// that also occurs in one of `privateTexts`. An error can quote a part of a private text,
    /// for example the start of a long AppleScript value.
    static func redacting(_ privateTexts: [String], in text: String) -> String {
        let characters = Array(text)
        func isQuote(_ range: Range<Int>) -> Bool {
            let quote = String(characters[range])
            return privateTexts.contains { $0.contains(quote) }
        }
        var result = ""
        var start = 0
        while start < characters.count {
            var end = start + minimumQuoteLength
            guard end <= characters.count, isQuote(start..<end) else {
                result.append(characters[start])
                start += 1
                continue
            }
            while end < characters.count, isQuote(start..<(end + 1)) {
                end += 1
            }
            result += "[redacted]"
            start = end
        }
        return result
    }
}

/// The run log as daily text files named `yyyy-MM-dd.log` in one folder.
public final class FileLog: Log {
    private let directory: URL
    private let timeZone: TimeZone

    /// Days and times are in `timeZone`.
    public init(directory: URL, timeZone: TimeZone = .current) {
        self.directory = directory
        self.timeZone = timeZone
    }

    public func write(_ entry: LogEntry) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: fileName(for: entry.time)).path
        let descriptor = open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw LogError(description: "Cannot open the log file at \(path): \(String(cString: strerror(errno)))")
        }
        defer { close(descriptor) }
        let data = Data((entry.line(timeZone: timeZone) + "\n").utf8)
        let written = data.withUnsafeBytes { Foundation.write(descriptor, $0.baseAddress, $0.count) }
        guard written == data.count else {
            throw LogError(description: "Cannot write to the log file at \(path): \(String(cString: strerror(errno)))")
        }
    }

    public func deleteFiles(before cutoff: Date) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        // A name `yyyy-MM-dd.log` sorts in the same order as its day.
        let cutoffName = fileName(for: cutoff)
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path)
        where name.wholeMatch(of: /\d{4}-\d{2}-\d{2}\.log/) != nil && name < cutoffName {
            try FileManager.default.removeItem(at: directory.appending(path: name))
        }
    }

    private func fileName(for time: Date) -> String {
        time.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()) + ".log"
    }
}

/// A failure to write or clean up the log files.
public struct LogError: Error, CustomStringConvertible {
    public var description: String
}
