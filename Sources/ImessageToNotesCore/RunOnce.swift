import Foundation

/// What one run did.
public struct RunReport: Equatable, Sendable {
    /// GUIDs of candidate Voice Messages that were already done.
    public var alreadyDone: [String] = []
    /// New Message Notes, in order of arrival of their Voice Messages.
    public var created: [CreatedMessageNote] = []
}

/// A Message Note that a run created, with the GUID of its Voice Message.
public struct CreatedMessageNote: Equatable, Sendable {
    public var guid: String
    public var noteID: String
}

/// How far back the first run goes. The backfill start is the first-run time minus this, and it never moves.
let backfillWindow: TimeInterval = 7 * 24 * 60 * 60

/// Does all the work of one run: every Voice Message from a Tracked Contact that is not done
/// becomes one Message Note, in order of arrival.
public func runOnce(
    configuration: Configuration,
    adapters: Adapters,
    timeZone: TimeZone = .current
) async throws -> RunReport {
    var report = RunReport()
    let backfillStart = try adapters.state.firstRunAt(recordingIfMissing: adapters.clock.now) - backfillWindow
    let candidates = try adapters.messages.voiceMessages(fromHandles: configuration.handles, since: backfillStart)
    for voiceMessage in candidates {
        guard let trackedContact = configuration.trackedContact(for: voiceMessage.handle) else { continue }
        if try adapters.state.record(for: voiceMessage.guid)?.status == .done {
            report.alreadyDone.append(voiceMessage.guid)
            continue
        }

        let firstSeenAt = adapters.clock.now
        let transcript = try await adapters.transcriber.transcribe(audioAt: voiceMessage.audioPath)
        let summary = try await adapters.summarizer.summarize(transcript)
        let noteID = try await adapters.notes.createMessageNote(
            inFolder: configuration.notesFolder,
            title: MessageNote.title(trackedContactName: trackedContact.name, sentAt: voiceMessage.sentAt, timeZone: timeZone),
            htmlBody: MessageNote.body(summary: summary)
        )
        try adapters.state.markDone(guid: voiceMessage.guid, noteID: noteID, firstSeenAt: firstSeenAt)
        report.created.append(CreatedMessageNote(guid: voiceMessage.guid, noteID: noteID))
    }
    return report
}
