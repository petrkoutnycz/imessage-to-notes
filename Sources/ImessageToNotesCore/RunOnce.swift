import Foundation

/// What one run did.
public struct RunReport: Equatable, Sendable {
    /// True when another run held the run lock, so this run did nothing.
    public var lockHeldByAnotherRun = false
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

/// How long the run log keeps its files.
let logRetention: TimeInterval = 30 * 24 * 60 * 60

/// Does all the work of one run: every Voice Message from a Tracked Contact that is not done
/// becomes one Message Note, in order of arrival. If another run is active, it does nothing.
/// The log records each step and holds no Transcript or Summary text.
public func runOnce(
    configuration: Configuration,
    adapters: Adapters,
    timeZone: TimeZone = .current
) async throws -> RunReport {
    var report = RunReport()
    let log = adapters.log
    let lockTaken: Bool
    do {
        lockTaken = try adapters.lock.tryLock()
    } catch {
        try? log.write(LogEntry(time: adapters.clock.now, event: .runFailed(error: String(describing: error))))
        throw error
    }
    guard lockTaken else {
        report.lockHeldByAnotherRun = true
        try log.write(LogEntry(time: adapters.clock.now, event: .runSkipped))
        return report
    }
    defer { adapters.lock.unlock() }
    try log.write(LogEntry(time: adapters.clock.now, event: .runStarted))
    // An old log file that stays is no reason to leave Voice Messages without a Message Note.
    do {
        try log.deleteFiles(before: adapters.clock.now - logRetention)
    } catch {
        try log.write(LogEntry(time: adapters.clock.now, event: .logCleanupFailed(error: String(describing: error))))
    }
    do {
        try await processVoiceMessages(configuration: configuration, adapters: adapters, timeZone: timeZone, report: &report)
    } catch let failure as StepFailure {
        // The log already holds the failed step.
        throw failure.error
    } catch {
        try? log.write(LogEntry(time: adapters.clock.now, event: .runFailed(error: String(describing: error))))
        throw error
    }
    try log.write(LogEntry(
        time: adapters.clock.now,
        event: .runFinished(created: report.created.count, alreadyDone: report.alreadyDone.count)
    ))
    return report
}

private func processVoiceMessages(
    configuration: Configuration,
    adapters: Adapters,
    timeZone: TimeZone,
    report: inout RunReport
) async throws {
    // The backfill start stays the same from run to run. Only an edit of `backfillDays` moves it.
    let backfillWindow = TimeInterval(configuration.backfillDays) * 24 * 60 * 60
    let backfillStart = try adapters.state.firstRunAt(recordingIfMissing: adapters.clock.now) - backfillWindow
    let candidates = try adapters.messages.voiceMessages(fromHandles: configuration.handles, since: backfillStart)
    for voiceMessage in candidates {
        guard let trackedContact = configuration.trackedContact(for: voiceMessage.handle) else { continue }
        var logEntry = VoiceMessageLogEntry(
            guid: voiceMessage.guid,
            trackedContactName: trackedContact.name,
            sentAt: voiceMessage.sentAt,
            status: .alreadyDone
        )
        func logStep(_ status: VoiceMessageStepStatus) throws {
            logEntry.status = status
            try adapters.log.write(LogEntry(time: adapters.clock.now, event: .voiceMessage(logEntry)))
        }
        /// Runs one step. If it fails, it logs the error with no quote of `privateTexts`.
        func perform<Result>(
            _ step: VoiceMessageStep,
            privateTexts: [String] = [],
            _ body: () async throws -> Result
        ) async throws -> Result {
            do {
                return try await body()
            } catch {
                try logStep(.failed(step: step, error: PrivateText.redacting(privateTexts, in: String(describing: error))))
                throw StepFailure(error: error)
            }
        }
        if try adapters.state.record(for: voiceMessage.guid)?.status == .done {
            report.alreadyDone.append(voiceMessage.guid)
            try logStep(.alreadyDone)
            continue
        }

        let firstSeenAt = adapters.clock.now
        let transcribed = try await perform(.transcribe) {
            try await adapters.transcriber.transcribe(audioAt: voiceMessage.audioPath)
        }
        logEntry.audioDuration = transcribed.audioDuration
        try logStep(.transcribed)
        let summary = try await perform(.summarize, privateTexts: [transcribed.transcript]) {
            try await adapters.summarizer.summarize(transcribed.transcript)
        }
        try logStep(.summarized)
        let htmlBody = MessageNote.body(summary: summary)
        let privateTexts = [transcribed.transcript, summary.text, htmlBody] + summary.actionItems
        let noteID = try await perform(.createMessageNote, privateTexts: privateTexts) {
            try await adapters.notes.createMessageNote(
                inFolder: configuration.notesFolder,
                title: MessageNote.title(trackedContactName: trackedContact.name, sentAt: voiceMessage.sentAt, timeZone: timeZone),
                htmlBody: htmlBody
            )
        }
        try adapters.state.markDone(guid: voiceMessage.guid, noteID: noteID, firstSeenAt: firstSeenAt)
        report.created.append(CreatedMessageNote(guid: voiceMessage.guid, noteID: noteID))
        try logStep(.done(noteID: noteID))
        // The Message Note exists, so a failed notification is no reason to stop the run.
        do {
            try await adapters.notifier.send(MessageNote.notification(
                trackedContactName: trackedContact.name,
                sentAt: voiceMessage.sentAt,
                noteID: noteID,
                timeZone: timeZone
            ))
        } catch {
            try logStep(.failed(step: .notify, error: String(describing: error)))
            continue
        }
        try logStep(.notified(noteID: noteID))
    }
}

/// A failed step of one Voice Message that the log already holds.
private struct StepFailure: Error {
    var error: any Error
}
