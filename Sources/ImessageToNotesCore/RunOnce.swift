import Foundation

public enum RunOutcome: Equatable, Sendable {
    case noVoiceMessage
    case alreadyDone(guid: String)
    case created(guid: String, noteID: String)
}

/// Does all the work of one run: the newest Voice Message from a Tracked Contact
/// becomes one Message Note, unless it is already done.
public func runOnce(
    configuration: Configuration,
    adapters: Adapters,
    timeZone: TimeZone = .current
) async throws -> RunOutcome {
    guard let voiceMessage = try adapters.messages.newestVoiceMessage(fromHandles: configuration.handles),
          let trackedContact = configuration.trackedContact(for: voiceMessage.handle)
    else {
        return .noVoiceMessage
    }
    if try adapters.state.record(for: voiceMessage.guid)?.status == .done {
        return .alreadyDone(guid: voiceMessage.guid)
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
    return .created(guid: voiceMessage.guid, noteID: noteID)
}
