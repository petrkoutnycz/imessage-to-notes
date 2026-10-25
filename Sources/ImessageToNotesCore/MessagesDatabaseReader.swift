import Foundation

/// The Messages Reader: reads Voice Messages from the Messages database, read-only.
public final class MessagesDatabaseReader: MessagesReader {
    /// `chat.style` for a one-to-one chat. Group chats use 43.
    static let directChatStyle = 45
    /// Seconds from 1970-01-01 to Apple's epoch, 2001-01-01.
    static let appleEpochOffset: TimeInterval = 978_307_200

    private let database: SQLiteDatabase
    private let homeDirectory: String

    public init(path: String, homeDirectory: String = NSHomeDirectory()) throws {
        database = try SQLiteDatabase(path: path, mode: .readOnly)
        self.homeDirectory = homeDirectory
    }

    public func newestVoiceMessage(fromHandles handles: [String]) throws -> VoiceMessage? {
        guard !handles.isEmpty else { return nil }
        let rows = try database.query(
            """
            SELECT m.guid, h.id, m.date, a.filename
            FROM message m
            JOIN handle h ON h.ROWID = m.handle_id
            JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            JOIN chat c ON c.ROWID = cmj.chat_id
            JOIN message_attachment_join maj ON maj.message_id = m.ROWID
            JOIN attachment a ON a.ROWID = maj.attachment_id
            WHERE m.is_audio_message = 1
              AND m.is_from_me = 0
              AND c.style = ?
              AND h.id IN (\(SQLiteDatabase.placeholders(count: handles.count)))
            ORDER BY m.date DESC
            LIMIT 1
            """,
            [.integer(Int64(Self.directChatStyle))] + handles.map { .text($0) }
        )
        guard let row = rows.first else { return nil }
        guard let guid = row[0].text, let handle = row[1].text, let date = row[2].integer,
              let filename = row[3].text
        else {
            throw SQLiteError(description: "Unexpected Voice Message row in the Messages database")
        }
        return VoiceMessage(
            guid: guid,
            handle: handle,
            sentAt: Self.date(fromAppleNanoseconds: date),
            audioPath: Self.expandingTilde(filename, homeDirectory: homeDirectory)
        )
    }

    /// Messages dates are nanoseconds since Apple's epoch.
    static func date(fromAppleNanoseconds nanoseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(nanoseconds) / 1_000_000_000 + appleEpochOffset)
    }

    /// Attachment paths in the Messages database start with `~/`.
    static func expandingTilde(_ path: String, homeDirectory: String) -> String {
        path.hasPrefix("~/") ? homeDirectory + path.dropFirst() : path
    }
}
