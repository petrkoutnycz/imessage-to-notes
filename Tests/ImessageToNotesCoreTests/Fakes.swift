import Foundation
import ImessageToNotesCore

final class FakeMessagesReader: MessagesReader {
    var voiceMessages: [VoiceMessage]

    init(_ voiceMessages: [VoiceMessage]) {
        self.voiceMessages = voiceMessages
    }

    func voiceMessages(fromHandles handles: [String], since start: Date) throws -> [VoiceMessage] {
        let wanted = Set(handles.map(Handle.normalized))
        return voiceMessages
            .filter { wanted.contains(Handle.normalized($0.handle)) && $0.sentAt >= start }
            .sorted { $0.sentAt < $1.sentAt }
    }
}

/// Every audio file is 42.5 seconds long.
final class FakeTranscriber: Transcriber {
    var transcripts: [String: String]

    init(_ transcripts: [String: String]) {
        self.transcripts = transcripts
    }

    func transcribe(audioAt path: String) async throws -> TranscribedAudio {
        guard let transcript = transcripts[path] else {
            throw FakeError("no audio at \(path)")
        }
        return TranscribedAudio(transcript: transcript, audioDuration: 42.5)
    }
}

final class FakeSummarizer: Summarizer {
    var summaries: [String: Summary]

    init(_ summaries: [String: Summary]) {
        self.summaries = summaries
    }

    func summarize(_ transcript: String) async throws -> Summary {
        guard let summary = summaries[transcript] else {
            throw FakeError("no summary for transcript")
        }
        return summary
    }
}

struct FakeMessageNote: Equatable {
    var id: String
    var notesFolder: String
    var title: String
    var body: String
}

final class FakeNotesWriter: NotesWriter {
    private(set) var messageNotes: [FakeMessageNote] = []
    /// When set, every new Message Note fails with the error that this returns for its HTML body.
    var failure: ((String) -> any Error)?

    func createMessageNote(inFolder notesFolder: String, title: String, htmlBody: String) async throws -> String {
        if let failure {
            throw failure(htmlBody)
        }
        let id = "x-coredata://note/\(messageNotes.count + 1)"
        messageNotes.append(FakeMessageNote(id: id, notesFolder: notesFolder, title: title, body: htmlBody))
        return id
    }
}

final class FakeStateStore: StateStore {
    private(set) var records: [String: VoiceMessageRecord] = [:]
    private var firstRunAt: Date?

    func record(for guid: String) throws -> VoiceMessageRecord? {
        records[guid]
    }

    func markDone(guid: String, noteID: String, firstSeenAt: Date) throws {
        records[guid] = VoiceMessageRecord(guid: guid, status: .done, noteID: noteID, firstSeenAt: firstSeenAt)
    }

    func firstRunAt(recordingIfMissing now: Date) throws -> Date {
        let firstRunAt = self.firstRunAt ?? now
        self.firstRunAt = firstRunAt
        return firstRunAt
    }
}

struct FakeClock: WallClock {
    var now: Date
}

struct FakeError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}

/// A run lock that no other run ever holds. When `failure` is set, taking the lock fails with it.
final class FakeRunLock: RunLock {
    var failure: (any Error)?

    func tryLock() throws -> Bool {
        if let failure {
            throw failure
        }
        return true
    }

    func unlock() {}
}

/// A log that keeps every entry in memory.
final class FakeLog: Log {
    private(set) var entries: [LogEntry] = []

    func write(_ entry: LogEntry) throws {
        entries.append(entry)
    }

    /// When set, the deletion of old log files fails with this error.
    var deleteFailure: (any Error)?

    func deleteFiles(before cutoff: Date) throws {
        if let deleteFailure {
            throw deleteFailure
        }
    }
}
