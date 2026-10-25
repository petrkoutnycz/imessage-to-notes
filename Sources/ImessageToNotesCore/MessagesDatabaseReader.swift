import Foundation

/// The Messages Reader: reads Voice Messages from the Messages database, read-only.
public final class MessagesDatabaseReader: MessagesReader {
    /// `chat.style` for a one-to-one chat. Group chats use 43.
    /// Many messages have no chat link at all. Such a message counts as a Direct Chat message,
    /// so only a link to a chat of another style excludes a Voice Message.
    static let directChatStyle = 45
    /// Seconds from 1970-01-01 to Apple's epoch, 2001-01-01.
    static let appleEpochOffset: TimeInterval = 978_307_200

    private let database: SQLiteDatabase
    private let homeDirectory: String

    public init(path: String, homeDirectory: String = NSHomeDirectory()) throws {
        database = try SQLiteDatabase(path: path, mode: .readOnly)
        self.homeDirectory = homeDirectory
    }

    public func voiceMessages(fromHandles handles: [String], since start: Date) throws -> [VoiceMessage] {
        let handleIDs = try matchingHandleIDs(handles)
        guard !handleIDs.isEmpty else { return [] }
        let rows = try database.query(
            """
            SELECT m.guid, h.id, m.date, a.filename
            FROM message m
            JOIN handle h ON h.ROWID = m.handle_id
            JOIN attachment a ON a.ROWID = (
                SELECT MIN(maj.attachment_id) FROM message_attachment_join maj WHERE maj.message_id = m.ROWID
            )
            WHERE m.is_audio_message = 1
              AND m.is_from_me = 0
              AND NOT EXISTS (
                  SELECT 1 FROM chat_message_join cmj JOIN chat c ON c.ROWID = cmj.chat_id
                  WHERE cmj.message_id = m.ROWID AND c.style IS NOT ?
              )
              AND m.date >= ?
              AND m.handle_id IN (\(SQLiteDatabase.placeholders(count: handleIDs.count)))
            ORDER BY m.date, m.ROWID
            """,
            [.integer(Int64(Self.directChatStyle)), .integer(Self.appleNanoseconds(from: start))]
                + handleIDs.map { .integer($0) }
        )
        return try rows.map { row in
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
    }

    /// The `handle` rows whose address matches one of `handles`, compared in normalized form.
    private func matchingHandleIDs(_ handles: [String]) throws -> [Int64] {
        let wanted = Set(handles.map(Handle.normalized).filter { !$0.isEmpty })
        return try database.query("SELECT ROWID, id FROM handle").compactMap { row in
            guard let id = row[1].text, wanted.contains(Handle.normalized(id)) else { return nil }
            return row[0].integer
        }
    }

    /// Messages dates are nanoseconds since Apple's epoch.
    static func date(fromAppleNanoseconds nanoseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(nanoseconds) / 1_000_000_000 + appleEpochOffset)
    }

    /// The inverse of `date(fromAppleNanoseconds:)`. It rounds up, so a message sent at `date` is not before it.
    /// The clamp keeps far dates such as `Date.distantPast` inside the range of `Int64`.
    static func appleNanoseconds(from date: Date) -> Int64 {
        let nanoseconds = ((date.timeIntervalSince1970 - appleEpochOffset) * 1_000_000_000).rounded(.up)
        return Int64(min(max(nanoseconds, -9e18), 9e18))
    }

    /// Attachment paths in the Messages database start with `~/`.
    static func expandingTilde(_ path: String, homeDirectory: String) -> String {
        path.hasPrefix("~/") ? homeDirectory + path.dropFirst() : path
    }
}
