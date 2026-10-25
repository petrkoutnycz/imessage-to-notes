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

final class FakeTranscriber: Transcriber {
    var transcripts: [String: String]

    init(_ transcripts: [String: String]) {
        self.transcripts = transcripts
    }

    func transcribe(audioAt path: String) async throws -> String {
        guard let transcript = transcripts[path] else {
            throw FakeError("no audio at \(path)")
        }
        return transcript
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

    func createMessageNote(inFolder notesFolder: String, title: String, htmlBody: String) async throws -> String {
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

/// A run lock that no other run ever holds.
final class FakeRunLock: RunLock {
    func tryLock() throws -> Bool { true }
    func unlock() {}
}
