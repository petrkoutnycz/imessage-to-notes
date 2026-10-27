import Foundation

/// What one run did.
public struct RunReport: Equatable, Sendable {
    /// True when another run held the run lock, so this run did nothing.
    public var lockHeldByAnotherRun = false
    /// GUIDs of candidate Voice Messages that were already done.
    public var alreadyDone: [String] = []
    /// New Message Notes, in order of arrival of their Voice Messages.
    public var created: [CreatedMessageNote] = []
    /// GUIDs of Voice Messages with a failed step that a later run tries again.
    public var pending: [String] = []
}

/// A Message Note that a run created, with the GUID of its Voice Message.
public struct CreatedMessageNote: Equatable, Sendable {
    public var guid: String
    public var noteID: String
    /// True for a fallback Message Note after a step failed for the whole retry window.
    public var isFallback: Bool
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
    } catch {
        try? log.write(LogEntry(time: adapters.clock.now, event: .runFailed(error: String(describing: error))))
        throw error
    }
    try log.write(LogEntry(
        time: adapters.clock.now,
        event: .runFinished(created: report.created.count, alreadyDone: report.alreadyDone.count, pending: report.pending.count)
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
                let loggedError = PrivateText.redacting(privateTexts, in: String(describing: error))
                try logStep(.failed(step: step, error: loggedError))
                throw StepFailure(step: step, error: error, loggedError: loggedError)
            }
        }
        /// Sends the notification about a new Message Note. The Message Note exists,
        /// so a failed notification is no reason to stop the run.
        func notify(_ notification: UserNotification) async throws {
            do {
                try await adapters.notifier.send(notification)
            } catch {
                try logStep(.failed(step: .notify, error: String(describing: error)))
                return
            }
            try logStep(.notified(noteID: notification.noteID))
        }
        let record = try adapters.state.record(for: voiceMessage.guid)
        if let record, record.status != .pending {
            report.alreadyDone.append(voiceMessage.guid)
            try logStep(.alreadyDone)
            continue
        }

        let firstSeenAt = record?.firstSeenAt ?? adapters.clock.now
        let title = MessageNote.title(trackedContactName: trackedContact.name, sentAt: voiceMessage.sentAt, timeZone: timeZone)
        func createMessageNote(htmlBody: String, privateTexts: [String]) async throws -> String {
            try await perform(.createMessageNote, privateTexts: privateTexts + [htmlBody]) {
                try await adapters.notes.createMessageNote(inFolder: configuration.notesFolder, title: title, htmlBody: htmlBody)
            }
        }
        // The Transcript of this run or of an earlier one. A fallback after a failed Summary shows it.
        var knownTranscript = record?.pendingTranscript?.transcript
        do {
            let transcribed: TranscribedAudio
            if let pendingTranscript = record?.pendingTranscript {
                transcribed = pendingTranscript
            } else {
                transcribed = try await perform(.transcribe) {
                    try await adapters.transcriber.transcribe(audioAt: voiceMessage.audioPath)
                }
                try adapters.state.storeTranscript(transcribed, guid: voiceMessage.guid, firstSeenAt: firstSeenAt)
                knownTranscript = transcribed.transcript
            }
            logEntry.audioDuration = transcribed.audioDuration
            if record?.pendingTranscript == nil {
                try logStep(.transcribed)
            }
            let summary = try await perform(.summarize, privateTexts: [transcribed.transcript]) {
                try await adapters.summarizer.summarize(transcribed.transcript)
            }
            try logStep(.summarized)
            let htmlBody = MessageNote.body(
                summary: summary,
                transcript: configuration.includeTranscript ? transcribed.transcript : nil
            )
            let noteID = try await createMessageNote(
                htmlBody: htmlBody,
                privateTexts: [transcribed.transcript, summary.text] + summary.actionItems
            )
            try adapters.state.markDone(guid: voiceMessage.guid, noteID: noteID, firstSeenAt: firstSeenAt)
            report.created.append(CreatedMessageNote(guid: voiceMessage.guid, noteID: noteID, isFallback: false))
            try logStep(.done(noteID: noteID))
            try await notify(MessageNote.notification(
                trackedContactName: trackedContact.name,
                sentAt: voiceMessage.sentAt,
                noteID: noteID,
                timeZone: timeZone
            ))
        } catch let failure as StepFailure {
            // Before the end of the retry window, the Voice Message stays pending, and the next run tries again.
            // A failed Message Note has no fallback, because a fallback Message Note fails the same way.
            var lastError = failure.loggedError
            var fallbackNote: (fallback: Fallback, noteID: String)?
            let retryWindow = TimeInterval(configuration.retryHours) * 60 * 60
            if adapters.clock.now.timeIntervalSince(firstSeenAt) >= retryWindow,
               let fallback = Fallback(failure, transcript: knownTranscript) {
                do {
                    let noteID = try await createMessageNote(
                        htmlBody: MessageNote.fallbackBody(fallback),
                        privateTexts: [knownTranscript].compactMap { $0 }
                    )
                    fallbackNote = (fallback, noteID)
                } catch let noteFailure as StepFailure {
                    lastError = noteFailure.loggedError
                }
            }
            try adapters.state.recordFailure(guid: voiceMessage.guid, error: lastError, firstSeenAt: firstSeenAt)
            guard let (fallback, noteID) = fallbackNote else {
                report.pending.append(voiceMessage.guid)
                continue
            }
            try adapters.state.markFallback(guid: voiceMessage.guid, noteID: noteID, firstSeenAt: firstSeenAt)
            report.created.append(CreatedMessageNote(guid: voiceMessage.guid, noteID: noteID, isFallback: true))
            try logStep(.fallback(noteID: noteID))
            try await notify(MessageNote.fallbackNotification(
                fallback,
                trackedContactName: trackedContact.name,
                sentAt: voiceMessage.sentAt,
                noteID: noteID,
                timeZone: timeZone
            ))
        }
    }
}

extension Fallback {
    /// The fallback for `failure`, or nil if the step has no fallback.
    fileprivate init?(_ failure: StepFailure, transcript: String?) {
        switch failure.step {
        case .transcribe:
            self = failure.error is MissingAudioFile ? .audioFileMissing : .transcriptionFailed
        case .summarize:
            guard let transcript else { return nil }
            self = .summaryFailed(transcript: transcript)
        case .createMessageNote, .notify:
            return nil
        }
    }
}

/// A failed step of one Voice Message that the log already holds.
private struct StepFailure: Error {
    var step: VoiceMessageStep
    var error: any Error
    /// The error as the log holds it, with no Transcript or Summary text.
    var loggedError: String
}
