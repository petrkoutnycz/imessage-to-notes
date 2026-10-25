import Foundation
import Testing
import ImessageToNotesCore

private let prague = TimeZone(identifier: "Europe/Prague")!

private let janaOnly = Configuration(
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

private let oneDay: TimeInterval = 24 * 60 * 60

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

@Test func oneRunTurnsEveryPendingVoiceMessageIntoMessageNoteInOrderOfArrival() async throws {
    let mac = FakeMac()
    mac.receive("GUID-1", sentAt: sentAt)
    try await mac.runOnce()

    mac.receive("GUID-3", sentAt: sentAt.addingTimeInterval(2 * 60 * 60))
    mac.receive("GUID-2", sentAt: sentAt.addingTimeInterval(60 * 60))
    try await mac.runOnce()

    #expect(mac.notesWriter.messageNotes.map(\.body) == [
        "<div>Shrnutí GUID-1</div>", "<div>Shrnutí GUID-2</div>", "<div>Shrnutí GUID-3</div>",
    ])
    #expect(try ["GUID-1", "GUID-2", "GUID-3"].map { try mac.state.record(for: $0)?.status } == [.done, .done, .done])
}

@Test func messageNoteNamesTrackedContactFoundByAnyOfTheirHandles() async throws {
    var mac = FakeMac()
    mac.configuration.trackedContacts = [
        TrackedContact(name: "Jana Nováková", handles: ["+420 777 123 456", "Jana@iCloud.com"]),
        TrackedContact(name: "Petr Novák", handles: ["+420 (602) 111-222"]),
    ]
    mac.receive("GUID-1", sentAt: sentAt, handle: "jana@icloud.com")
    mac.receive("GUID-2", sentAt: sentAt.addingTimeInterval(60 * 60), handle: "+420602111222")
    mac.receive("GUID-3", sentAt: sentAt.addingTimeInterval(2 * 60 * 60), handle: "+420777123456")

    try await mac.runOnce()

    #expect(mac.notesWriter.messageNotes.map(\.title) == [
        "Jana Nováková – 2026-10-20 08:30", "Petr Novák – 2026-10-20 09:30", "Jana Nováková – 2026-10-20 10:30",
    ])
}

@Test func firstRunGoesBackSevenDaysAndLaterRunsKeepThatStart() async throws {
    var mac = FakeMac()
    mac.receive("TOO-OLD", sentAt: runAt.addingTimeInterval(-7 * oneDay - 60))
    mac.receive("IN-WINDOW", sentAt: runAt.addingTimeInterval(-7 * oneDay + 60))
    try await mac.runOnce()

    // Ten days later, after sleep. One Voice Message from before the first run arrives only now.
    mac.clock.now = runAt.addingTimeInterval(10 * oneDay)
    mac.receive("ARRIVES-LATE", sentAt: runAt.addingTimeInterval(-6 * oneDay))
    mac.receive("DURING-SLEEP", sentAt: runAt.addingTimeInterval(9 * oneDay))
    try await mac.runOnce()

    #expect(mac.notesWriter.messageNotes.map(\.body) == [
        "<div>Shrnutí IN-WINDOW</div>", "<div>Shrnutí ARRIVES-LATE</div>", "<div>Shrnutí DURING-SLEEP</div>",
    ])
}

@Test func backfillStartStaysAfterStateStoreReopens() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let statePath = directory.appending(path: "state.sqlite").path
    var mac = FakeMac()
    try await mac.runOnce(state: SQLiteStateStore(path: statePath))

    mac.clock.now = runAt.addingTimeInterval(10 * oneDay)
    mac.receive("ARRIVES-LATE", sentAt: runAt.addingTimeInterval(-6 * oneDay))
    try await mac.runOnce(state: SQLiteStateStore(path: statePath))

    #expect(mac.notesWriter.messageNotes.map(\.body) == ["<div>Shrnutí ARRIVES-LATE</div>"])
}

/// One set of fake adapters that several runs share, like the Mac between two runs.
private struct FakeMac {
    let messages: FakeMessagesReader
    let transcriber: FakeTranscriber
    let summarizer: FakeSummarizer
    let notesWriter = FakeNotesWriter()
    let state = FakeStateStore()
    var clock = FakeClock(now: runAt)
    var configuration = janaOnly

    init(voiceMessages: [VoiceMessage] = [], transcripts: [String: String] = [:], summaries: [String: Summary] = [:]) {
        messages = FakeMessagesReader(voiceMessages)
        transcriber = FakeTranscriber(transcripts)
        summarizer = FakeSummarizer(summaries)
    }

    /// A new Voice Message arrives. Its Transcript is "Přepis <guid>" and its Summary is "Shrnutí <guid>".
    func receive(_ guid: String, sentAt: Date, handle: String = "+420777123456") {
        let audioPath = "/attachments/\(guid)/Audio Message.caf"
        messages.voiceMessages.append(VoiceMessage(guid: guid, handle: handle, sentAt: sentAt, audioPath: audioPath))
        transcriber.transcripts[audioPath] = "Přepis \(guid)"
        summarizer.summaries["Přepis \(guid)"] = Summary(text: "Shrnutí \(guid)", actionItems: [])
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
