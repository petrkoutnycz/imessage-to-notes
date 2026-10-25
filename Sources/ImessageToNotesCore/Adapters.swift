import Foundation

/// One Voice Message as the Messages database reports it.
public struct VoiceMessage: Equatable, Sendable {
    public var guid: String
    public var handle: String
    public var sentAt: Date
    public var audioPath: String

    public init(guid: String, handle: String, sentAt: Date, audioPath: String) {
        self.guid = guid
        self.handle = handle
        self.sentAt = sentAt
        self.audioPath = audioPath
    }
}

/// The Summarizer result for one Transcript.
public struct Summary: Equatable, Sendable {
    public var text: String
    public var actionItems: [String]

    public init(text: String, actionItems: [String]) {
        self.text = text
        self.actionItems = actionItems
    }
}

public enum VoiceMessageStatus: String, Sendable {
    case done
}

/// What the State Store knows about one Voice Message.
public struct VoiceMessageRecord: Equatable, Sendable {
    public var guid: String
    public var status: VoiceMessageStatus
    public var noteID: String?
    public var firstSeenAt: Date

    public init(guid: String, status: VoiceMessageStatus, noteID: String?, firstSeenAt: Date) {
        self.guid = guid
        self.status = status
        self.noteID = noteID
        self.firstSeenAt = firstSeenAt
    }
}

public protocol MessagesReader {
    /// Voice Messages from the given Handles, sent on or after `start`, in order of arrival.
    func voiceMessages(fromHandles handles: [String], since start: Date) throws -> [VoiceMessage]
}

public protocol Transcriber {
    func transcribe(audioAt path: String) async throws -> String
}

public protocol Summarizer {
    func summarize(_ transcript: String) async throws -> Summary
}

public protocol NotesWriter {
    /// Creates a Message Note and returns its note ID.
    func createMessageNote(inFolder notesFolder: String, title: String, htmlBody: String) async throws -> String
}

public protocol StateStore {
    func record(for guid: String) throws -> VoiceMessageRecord?
    func markDone(guid: String, noteID: String, firstSeenAt: Date) throws
    /// The time of the first run. The first call records `now` and returns it.
    func firstRunAt(recordingIfMissing now: Date) throws -> Date
}

public protocol WallClock {
    var now: Date { get }
}

public struct SystemClock: WallClock {
    public init() {}
    public var now: Date { Date() }
}

/// Everything outside the program that one run talks to.
public struct Adapters {
    public var messages: any MessagesReader
    public var transcriber: any Transcriber
    public var summarizer: any Summarizer
    public var notes: any NotesWriter
    public var state: any StateStore
    public var clock: any WallClock

    public init(
        messages: any MessagesReader,
        transcriber: any Transcriber,
        summarizer: any Summarizer,
        notes: any NotesWriter,
        state: any StateStore,
        clock: any WallClock
    ) {
        self.messages = messages
        self.transcriber = transcriber
        self.summarizer = summarizer
        self.notes = notes
        self.state = state
        self.clock = clock
    }
}
