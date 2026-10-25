import Foundation
import Testing
import ImessageToNotesCore

private let prague = TimeZone(identifier: "Europe/Prague")!

private let configuration = Configuration(
    trackedContacts: [TrackedContact(name: "Jana Nováková", handles: ["+420777123456", "jana@icloud.com"])],
    notesFolder: "Hlasové zprávy",
    claudeModel: "claude-sonnet-5-5"
)

/// 2026-10-20 06:30 UTC, which is 08:30 in Prague.
private let sentAt = Date(timeIntervalSince1970: 1_792_477_800)
private let runAt = Date(timeIntervalSince1970: 1_792_500_000)

private let voiceMessage = VoiceMessage(
    guid: "GUID-1",
    handle: "+420777123456",
    sentAt: sentAt,
    audioPath: "/attachments/GUID-1/Audio Message.caf"
)

private let transcript = "Ahoj, nezapomeň zítra v deset vyzvednout balík na poště a zavolej mamince."

@Test func voiceMessageBecomesMessageNoteWithSummaryAndActionItems() async throws {
    let mac = FakeMac(
        voiceMessages: [voiceMessage],
        transcripts: [voiceMessage.audioPath: transcript],
        summaries: [transcript: Summary(
            text: "Jana připomíná vyzvednutí balíku. Také prosí o telefonát mamince.",
            actionItems: ["Vyzvednout balík na poště zítra v 10:00", "Zavolat mamince"]
        )]
    )

    try await mac.runOnce()

    #expect(mac.notesWriter.messageNotes == [FakeMessageNote(
        id: "x-coredata://note/1",
        notesFolder: "Hlasové zprávy",
        title: "Jana Nováková – 2026-10-20 08:30",
        body: "<div>Jana připomíná vyzvednutí balíku. Také prosí o telefonát mamince.</div>"
            + "<div><br></div><div><b>Úkoly</b></div>"
            + "<ul><li>Vyzvednout balík na poště zítra v 10:00</li><li>Zavolat mamince</li></ul>"
    )])
    #expect(try mac.state.record(for: "GUID-1") == VoiceMessageRecord(
        guid: "GUID-1", status: .done, noteID: "x-coredata://note/1", firstSeenAt: runAt
    ))
}

@Test func messageNoteWithoutActionItemsHasNoActionItemsList() async throws {
    let mac = FakeMac(
        voiceMessages: [voiceMessage],
        transcripts: [voiceMessage.audioPath: transcript],
        summaries: [transcript: Summary(text: "Jana jen pozdravuje & posílá <3.", actionItems: [])]
    )

    try await mac.runOnce()

    #expect(mac.notesWriter.messageNotes.map(\.body) == ["<div>Jana jen pozdravuje &amp; posílá &lt;3.</div>"])
}

@Test func doneVoiceMessageNeverGetsSecondMessageNote() async throws {
    var mac = FakeMac(
        voiceMessages: [voiceMessage],
        transcripts: [voiceMessage.audioPath: transcript],
        summaries: [transcript: Summary(text: "Jana připomíná balík.", actionItems: [])]
    )

    try await mac.runOnce()
    mac.clock.now = runAt.addingTimeInterval(5 * 60)
    try await mac.runOnce()

    #expect(mac.notesWriter.messageNotes.count == 1)
    #expect(try mac.state.record(for: "GUID-1")?.firstSeenAt == runAt)
}

@Test func doneVoiceMessageStaysDoneAfterStateStoreReopens() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let statePath = directory.appending(path: "state.sqlite").path
    let mac = FakeMac(
        voiceMessages: [voiceMessage],
        transcripts: [voiceMessage.audioPath: transcript],
        summaries: [transcript: Summary(text: "Jana připomíná balík.", actionItems: [])]
    )

    try await mac.runOnce(state: SQLiteStateStore(path: statePath))
    try await mac.runOnce(state: SQLiteStateStore(path: statePath))

    #expect(mac.notesWriter.messageNotes.count == 1)
    #expect(try SQLiteStateStore(path: statePath).record(for: "GUID-1") == VoiceMessageRecord(
        guid: "GUID-1", status: .done, noteID: "x-coredata://note/1", firstSeenAt: runAt
    ))
}

/// One set of fake adapters that several runs share, like the Mac between two runs.
private struct FakeMac {
    let messages: FakeMessagesReader
    let transcriber: FakeTranscriber
    let summarizer: FakeSummarizer
    let notesWriter = FakeNotesWriter()
    let state = FakeStateStore()
    var clock = FakeClock(now: runAt)

    init(voiceMessages: [VoiceMessage], transcripts: [String: String], summaries: [String: Summary]) {
        messages = FakeMessagesReader(voiceMessages)
        transcriber = FakeTranscriber(transcripts)
        summarizer = FakeSummarizer(summaries)
    }

    func runOnce(state: (any StateStore)? = nil) async throws {
        _ = try await ImessageToNotesCore.runOnce(
            configuration: configuration,
            adapters: Adapters(
                messages: messages,
                transcriber: transcriber,
                summarizer: summarizer,
                notes: notesWriter,
                state: state ?? self.state,
                clock: clock
            ),
            timeZone: prague
        )
    }
}
