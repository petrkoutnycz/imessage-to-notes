import Foundation
import SQLite3
import Testing
import ImessageToNotesCore

/// Nanoseconds since 2001-01-01 for 2026-10-20 06:30 UTC.
private let appleDate: Int64 = 814_170_600_000_000_000
private let oneHour: Int64 = 3_600_000_000_000

@Test func readerReturnsNewestVoiceMessageFromTrackedHandle() throws {
    let fixture = try MessagesFixture()
    let jana = try fixture.handle("+420777123456")
    let other = try fixture.handle("+420600000000")
    let direct = try fixture.chat(style: 45)
    let group = try fixture.chat(style: 43)
    let otherChat = try fixture.chat(style: 45)

    try fixture.message("OLDER", handle: jana, chat: direct, audio: true, date: appleDate - oneHour,
                        attachment: "~/Library/Messages/Attachments/aa/00/OLDER/Audio Message.caf")
    try fixture.message("NEWEST", handle: jana, chat: direct, audio: true, date: appleDate,
                        attachment: "~/Library/Messages/Attachments/ab/01/NEWEST/Audio Message.caf")
    try fixture.message("TEXT", handle: jana, chat: direct, audio: false, date: appleDate + oneHour)
    try fixture.message("GROUP", handle: jana, chat: group, audio: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ac/02/GROUP/Audio Message.caf")
    try fixture.message("FROM-ME", handle: jana, chat: direct, audio: true, fromMe: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ad/03/FROM-ME/Audio Message.caf")
    try fixture.message("OTHER", handle: other, chat: otherChat, audio: true, date: appleDate + oneHour,
                        attachment: "~/Library/Messages/Attachments/ae/04/OTHER/Audio Message.caf")

    let reader = try MessagesDatabaseReader(path: fixture.path, homeDirectory: "/Users/tester")

    #expect(try reader.newestVoiceMessage(fromHandles: ["+420777123456"]) == VoiceMessage(
        guid: "NEWEST",
        handle: "+420777123456",
        sentAt: Date(timeIntervalSince1970: 1_792_477_800),
        audioPath: "/Users/tester/Library/Messages/Attachments/ab/01/NEWEST/Audio Message.caf"
    ))
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

    func message(
        _ guid: String, handle: Int64, chat: Int64, audio: Bool, fromMe: Bool = false, date: Int64,
        attachment: String? = nil
    ) throws {
        let rowID = newID()
        try execute("""
            INSERT INTO message (ROWID, guid, handle_id, is_audio_message, is_from_me, date)
                VALUES (\(rowID), '\(guid)', \(handle), \(audio ? 1 : 0), \(fromMe ? 1 : 0), \(date));
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (\(chat), \(rowID));
            """)
        if let attachment {
            let attachmentID = newID()
            try execute("""
                INSERT INTO attachment (ROWID, filename) VALUES (\(attachmentID), '\(attachment)');
                INSERT INTO message_attachment_join (message_id, attachment_id) VALUES (\(rowID), \(attachmentID));
                """)
        }
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
