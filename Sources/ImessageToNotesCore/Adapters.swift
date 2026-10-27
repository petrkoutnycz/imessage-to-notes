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

/// The Transcriber result for one Voice Message.
public struct TranscribedAudio: Equatable, Sendable {
    public var transcript: String
    /// The length of the audio in seconds.
    public var audioDuration: TimeInterval

    public init(transcript: String, audioDuration: TimeInterval) {
        self.transcript = transcript
        self.audioDuration = audioDuration
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
    /// A step failed, and a later run tries again.
    case pending
    case done
    /// A step failed for the whole retry window, and the Voice Message has a fallback Message Note.
    case fallback
}

/// What the State Store knows about one Voice Message.
public struct VoiceMessageRecord: Equatable, Sendable {
    public var guid: String
    public var status: VoiceMessageStatus
    public var noteID: String?
    public var firstSeenAt: Date
    /// The number of runs in which a step failed.
    public var failedAttempts: Int
    /// The error of the last failed step, with no Transcript or Summary text.
    public var lastError: String?
    /// The Transcript of a pending Voice Message, so a retry does not transcribe again.
    /// The State Store erases it when the Message Note exists.
    public var pendingTranscript: TranscribedAudio?

    public init(
        guid: String,
        status: VoiceMessageStatus,
        noteID: String?,
        firstSeenAt: Date,
        failedAttempts: Int = 0,
        lastError: String? = nil,
        pendingTranscript: TranscribedAudio? = nil
    ) {
        self.guid = guid
        self.status = status
        self.noteID = noteID
        self.firstSeenAt = firstSeenAt
        self.failedAttempts = failedAttempts
        self.lastError = lastError
        self.pendingTranscript = pendingTranscript
    }
}

public protocol MessagesReader {
    /// Voice Messages from the given Handles, sent on or after `start`, in order of arrival.
    func voiceMessages(fromHandles handles: [String], since start: Date) throws -> [VoiceMessage]
}

/// The audio file of a Voice Message is not on this Mac, for example because it is still downloading.
public struct MissingAudioFile: Error, CustomStringConvertible {
    public var path: String

    public init(path: String) {
        self.path = path
    }

    public var description: String { "The audio file is missing: \(path)" }
}

public protocol Transcriber {
    func transcribe(audioAt path: String) async throws -> TranscribedAudio
}

public protocol Summarizer {
    func summarize(_ transcript: String) async throws -> Summary
}

public protocol NotesWriter {
    /// True if the iCloud account has a folder with the name `notesFolder`.
    func notesFolderExists(_ notesFolder: String) async throws -> Bool
    /// Creates a Message Note and returns its note ID.
    func createMessageNote(inFolder notesFolder: String, title: String, htmlBody: String) async throws -> String
}

public protocol StateStore {
    func record(for guid: String) throws -> VoiceMessageRecord?
    /// Keeps the Transcript of a Voice Message that has no Message Note yet.
    func storeTranscript(_ transcribed: TranscribedAudio, guid: String, firstSeenAt: Date) throws
    /// Leaves the Voice Message pending and counts one more failed attempt.
    func recordFailure(guid: String, error: String, firstSeenAt: Date) throws
    /// Marks the Voice Message done and erases its pending Transcript.
    func markDone(guid: String, noteID: String, firstSeenAt: Date) throws
    /// Marks the Voice Message fallback and erases its pending Transcript.
    func markFallback(guid: String, noteID: String, firstSeenAt: Date) throws
    /// The time of the first run. The first call records `now` and returns it.
    func firstRunAt(recordingIfMissing now: Date) throws -> Date
    /// The time of the last notification about a missing Notes Folder, or nil if none was sent.
    func lastNotesFolderNotificationAt() throws -> Date?
    /// Records `time` as the time of the last notification about a missing Notes Folder.
    func recordNotesFolderNotification(at time: Date) throws
}

/// Makes sure that only one run is active at a time.
public protocol RunLock {
    /// Takes the lock and returns true, or returns false at once if another run holds it.
    func tryLock() throws -> Bool
    func unlock()
}

/// The run log. An entry has no field for Transcript or Summary text.
public protocol Log {
    /// Appends `entry` to the log file of the day of its time.
    func write(_ entry: LogEntry) throws
    /// Deletes the log files of the days before the day of `cutoff`.
    func deleteFiles(before cutoff: Date) throws
}

/// A macOS notification. It holds no Transcript or Summary text, because it can show on the lock screen.
public struct UserNotification: Equatable, Sendable {
    public var title: String
    public var body: String
    /// The Message Note that a click on the notification opens, or nil if a click opens nothing.
    public var noteID: String?

    public init(title: String, body: String, noteID: String?) {
        self.title = title
        self.body = body
        self.noteID = noteID
    }
}

public protocol Notifier {
    func send(_ notification: UserNotification) async throws
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
    public var lock: any RunLock
    public var log: any Log
    public var notifier: any Notifier

    public init(
        messages: any MessagesReader,
        transcriber: any Transcriber,
        summarizer: any Summarizer,
        notes: any NotesWriter,
        state: any StateStore,
        clock: any WallClock,
        lock: any RunLock,
        log: any Log,
        notifier: any Notifier
    ) {
        self.messages = messages
        self.transcriber = transcriber
        self.summarizer = summarizer
        self.notes = notes
        self.state = state
        self.clock = clock
        self.lock = lock
        self.log = log
        self.notifier = notifier
    }
}
