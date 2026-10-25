import Foundation
import SQLite3
import Testing
import ImessageToNotesCore

/// Nanoseconds since 2001-01-01 for 2026-10-20 06:30 UTC.
private let appleDate: Int64 = 814_170_600_000_000_000
private let oneHour: Int64 = 3_600_000_000_000

private let longAgo = Date(timeIntervalSince1970: 0)

@Test func readerReturnsIncomingVoiceMessagesFromDirectChatsInOrderOfArrival() throws {
    let fixture = try MessagesFixture()
    let jana = try fixture.handle("+420777123456")
    let direct = try fixture.chat(style: 45)
    let group = try fixture.chat(style: 43)

    try fixture.message("NEWER", handle: jana, chat: direct, audio: true, date: appleDate,
                        attachment: "~/Library/Messages/Attachments/ab/01/NEWER/Audio Message.caf")
    try fixture.message("OLDER", handle: jana, chat: direct, audio: true, date: appleDate - oneHour,
                        attachment: "~/Library/Messages/Attachments/aa/00/OLDER/Audio Message.caf")
    try fixture.message("TEXT", handle: jana, chat: direct, audio: false, date: appleDate + oneHour)
    try fixture.message("VIDEO", handle: jana, chat: direct, audio: false, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/af/05/VIDEO/IMG_0001.MOV")
    try fixture.message("AUDIO-FILE", handle: jana, chat: direct, audio: false, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/b0/06/AUDIO-FILE/song.m4a")
    try fixture.message("GROUP", handle: jana, chat: group, audio: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ac/02/GROUP/Audio Message.caf")
    try fixture.message("FROM-ME", handle: jana, chat: direct, audio: true, fromMe: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ad/03/FROM-ME/Audio Message.caf")

    let reader = try MessagesDatabaseReader(path: fixture.path, homeDirectory: "/Users/tester")

    #expect(try reader.voiceMessages(fromHandles: ["+420777123456"], since: longAgo) == [
        VoiceMessage(
            guid: "OLDER",
            handle: "+420777123456",
            sentAt: Date(timeIntervalSince1970: 1_792_474_200),
            audioPath: "/Users/tester/Library/Messages/Attachments/aa/00/OLDER/Audio Message.caf"
        ),
        VoiceMessage(
            guid: "NEWER",
            handle: "+420777123456",
            sentAt: Date(timeIntervalSince1970: 1_792_477_800),
            audioPath: "/Users/tester/Library/Messages/Attachments/ab/01/NEWER/Audio Message.caf"
        ),
    ])
}

@Test func readerSkipsVoiceMessagesSentBeforeStart() throws {
    let fixture = try MessagesFixture()
    let jana = try fixture.handle("+420777123456")
    let direct = try fixture.chat(style: 45)
    let oneSecond: Int64 = 1_000_000_000

    try fixture.message("BEFORE", handle: jana, chat: direct, audio: true, date: appleDate - oneSecond,
                        attachment: "~/Library/Messages/Attachments/aa/00/BEFORE/Audio Message.caf")
    try fixture.message("AT-START", handle: jana, chat: direct, audio: true, date: appleDate,
                        attachment: "~/Library/Messages/Attachments/ab/01/AT-START/Audio Message.caf")
    try fixture.message("AFTER", handle: jana, chat: direct, audio: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ac/02/AFTER/Audio Message.caf")

    let reader = try MessagesDatabaseReader(path: fixture.path)
    // 2026-10-20 06:30 UTC, the same instant as `appleDate`.
    let start = Date(timeIntervalSince1970: 1_792_477_800)

    #expect(try reader.voiceMessages(fromHandles: ["+420777123456"], since: start).map(\.guid) == ["AT-START", "AFTER"])
}

@Test func readerMatchesPhoneHandlesWithoutFormatAndEmailHandlesWithoutCase() throws {
    let fixture = try MessagesFixture()
    let phone = try fixture.handle("+420777123456")
    let email = try fixture.handle("jana.novakova@icloud.com")
    let other = try fixture.handle("+420600000000")

    try fixture.message("PHONE", handle: phone, chat: try fixture.chat(style: 45), audio: true, date: appleDate,
                        attachment: "~/Library/Messages/Attachments/aa/00/PHONE/Audio Message.caf")
    try fixture.message("EMAIL", handle: email, chat: try fixture.chat(style: 45), audio: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ab/01/EMAIL/Audio Message.caf")
    try fixture.message("OTHER", handle: other, chat: try fixture.chat(style: 45), audio: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ac/02/OTHER/Audio Message.caf")

    let reader = try MessagesDatabaseReader(path: fixture.path)
    let voiceMessages = try reader.voiceMessages(
        fromHandles: ["+420 777-123 456", "Jana.Novakova@iCloud.com"],
        since: longAgo
    )

    #expect(voiceMessages.map(\.guid) == ["PHONE", "EMAIL"])
    #expect(voiceMessages.map(\.handle) == ["+420777123456", "jana.novakova@icloud.com"])
}

/// Many real messages have no row in `chat_message_join`. Only a link to a group chat excludes one.
@Test func readerCountsVoiceMessageWithNoChatLinkAsDirectChat() throws {
    let fixture = try MessagesFixture()
    let jana = try fixture.handle("+420777123456")

    try fixture.message("NO-CHAT", handle: jana, chat: nil, audio: true, date: appleDate,
                        attachment: "~/Library/Messages/Attachments/aa/00/NO-CHAT/Audio Message.caf")
    try fixture.message("GROUP", handle: jana, chat: try fixture.chat(style: 43), audio: true, date: appleDate,
                        attachment: "~/Library/Messages/Attachments/ab/01/GROUP/Audio Message.caf")

    let reader = try MessagesDatabaseReader(path: fixture.path)

    #expect(try reader.voiceMessages(fromHandles: ["+420777123456"], since: longAgo).map(\.guid) == ["NO-CHAT"])
}

@Test func readerReturnsVoiceMessageWithTwoAttachmentRowsOnce() throws {
    let fixture = try MessagesFixture()
    let jana = try fixture.handle("+420777123456")
    let message = try fixture.message("TWICE", handle: jana, chat: try fixture.chat(style: 45), audio: true, date: appleDate,
                                      attachment: "~/Library/Messages/Attachments/aa/00/TWICE/Audio Message.caf")
    try fixture.attach("~/Library/Messages/Attachments/aa/00/TWICE/Audio Message copy.caf", to: message)

    let reader = try MessagesDatabaseReader(path: fixture.path, homeDirectory: "/Users/tester")

    #expect(try reader.voiceMessages(fromHandles: ["+420777123456"], since: longAgo).map(\.audioPath) == [
        "/Users/tester/Library/Messages/Attachments/aa/00/TWICE/Audio Message.caf",
    ])
}

/// A SQLite file with the parts of the Messages database schema that the reader uses.
private final class MessagesFixture {
    let path: String
    private let handle: OpaquePointer
    private var nextID: Int64 = 1

    init() throws {
        path = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).db").path
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let handle else { throw FakeError("cannot open fixture") }
        self.handle = handle
        try execute("""
            CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT NOT NULL);
            CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, style INTEGER);
            CREATE TABLE message (
                ROWID INTEGER PRIMARY KEY, guid TEXT UNIQUE NOT NULL, handle_id INTEGER DEFAULT 0,
                is_audio_message INTEGER DEFAULT 0, is_from_me INTEGER DEFAULT 0, date INTEGER
            );
            CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
            CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, filename TEXT);
            CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
            """)
    }

    deinit {
        sqlite3_close(handle)
        try? FileManager.default.removeItem(atPath: path)
    }

    func handle(_ id: String) throws -> Int64 {
        let rowID = newID()
        try execute("INSERT INTO handle (ROWID, id) VALUES (\(rowID), '\(id)')")
        return rowID
    }

    func chat(style: Int) throws -> Int64 {
        let rowID = newID()
        try execute("INSERT INTO chat (ROWID, style) VALUES (\(rowID), \(style))")
        return rowID
    }

    @discardableResult
    func message(
        _ guid: String, handle: Int64, chat: Int64?, audio: Bool, fromMe: Bool = false, date: Int64,
        attachment: String? = nil
    ) throws -> Int64 {
        let rowID = newID()
        try execute("""
            INSERT INTO message (ROWID, guid, handle_id, is_audio_message, is_from_me, date)
                VALUES (\(rowID), '\(guid)', \(handle), \(audio ? 1 : 0), \(fromMe ? 1 : 0), \(date));
            """)
        if let chat {
            try execute("INSERT INTO chat_message_join (chat_id, message_id) VALUES (\(chat), \(rowID))")
        }
        if let attachment {
            try attach(attachment, to: rowID)
        }
        return rowID
    }

    func attach(_ filename: String, to message: Int64) throws {
        let attachmentID = newID()
        try execute("""
            INSERT INTO attachment (ROWID, filename) VALUES (\(attachmentID), '\(filename)');
            INSERT INTO message_attachment_join (message_id, attachment_id) VALUES (\(message), \(attachmentID));
            """)
    }

    private func newID() -> Int64 {
        defer { nextID += 1 }
        return nextID
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw FakeError(String(cString: sqlite3_errmsg(handle)))
        }
    }
}
