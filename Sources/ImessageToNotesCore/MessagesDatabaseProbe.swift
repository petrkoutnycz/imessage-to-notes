import Foundation

/// Reports how the real Messages database matches the markers that the Messages Reader expects.
/// It prints metadata only, never message text.
public struct MessagesDatabaseProbe {
    /// The audio attachment of a message with `is_audio_message = 1`.
    public struct AudioAttachment {
        public var guid: String
        public var path: String
    }

    private static let expectedColumns: [(table: String, columns: [String])] = [
        ("message", ["ROWID", "guid", "handle_id", "is_audio_message", "is_from_me", "date"]),
        ("handle", ["ROWID", "id"]),
        ("chat", ["ROWID", "style"]),
        ("chat_message_join", ["chat_id", "message_id"]),
        ("message_attachment_join", ["message_id", "attachment_id"]),
        ("attachment", ["ROWID", "filename", "uti", "mime_type", "transfer_name"]),
    ]

    private let database: SQLiteDatabase
    private let homeDirectory: String

    public init(path: String, homeDirectory: String = NSHomeDirectory()) throws {
        database = try SQLiteDatabase(path: path, mode: .readOnly)
        self.homeDirectory = homeDirectory
    }

    /// Returns report lines and the newest audio messages from the given Handles.
    public func report(handles: [String]) throws -> (lines: [String], audioAttachments: [AudioAttachment]) {
        var lines: [String] = []

        for (table, columns) in Self.expectedColumns {
            let present = Set(try database.query("SELECT name FROM pragma_table_info(?)", [.text(table)]).compactMap { $0[0].text })
            let missing = columns.filter { !present.contains($0) }
            lines.append("table \(table): " + (missing.isEmpty ? "all expected columns present" : "MISSING \(missing)"))
        }

        for row in try database.query("SELECT style, COUNT(*) FROM chat GROUP BY style") {
            lines.append("chat style \(row[0].integer.map(String.init) ?? "null"): \(row[1].integer ?? 0) chats")
        }
        let audioCount = try database.query("SELECT COUNT(*) FROM message WHERE is_audio_message = 1")
        lines.append("messages with is_audio_message = 1: \(audioCount.first?[0].integer ?? 0)")
        let linkCheck = try database.query("""
            SELECT
                SUM(NOT EXISTS (SELECT 1 FROM chat_message_join cmj WHERE cmj.message_id = m.ROWID)),
                SUM(m.cache_roomnames IS NOT NULL),
                (SELECT COUNT(*) FROM message g JOIN chat_message_join j ON j.message_id = g.ROWID
                    JOIN chat c ON c.ROWID = j.chat_id WHERE c.style = 43 AND g.cache_roomnames IS NULL)
            FROM message m
            """)
        if let row = linkCheck.first {
            lines.append("messages with no chat link: \(row[0].integer ?? 0), messages with cache_roomnames set: "
                + "\(row[1].integer ?? 0), group-chat messages with no cache_roomnames: \(row[2].integer ?? 0)")
        }

        // Senders of audio messages, masked, to show how the database writes a Handle.
        let normalizedHandles = Set(handles.map(Handle.normalized))
        let senders = try database.query("""
            SELECT h.id, COUNT(*) FROM message m JOIN handle h ON h.ROWID = m.handle_id
            WHERE m.is_audio_message = 1 AND m.is_from_me = 0 GROUP BY h.id
            """)
        for row in senders {
            let id = row[0].text ?? ""
            let exact = handles.contains(id) ? "exact match" : "no exact match"
            let normalized = normalizedHandles.contains(Handle.normalized(id)) ? "normalized match" : "no normalized match"
            lines.append("audio sender \(Self.masked(id)): \(row[1].integer ?? 0) messages, \(exact), \(normalized)")
        }

        guard !handles.isEmpty else { return (lines, []) }
        let rows = try database.query(
            """
            SELECT m.guid, h.id, m.is_from_me, m.date, c.style, a.filename, a.uti, a.mime_type, a.transfer_name,
                   (SELECT COUNT(*) FROM chat_handle_join chj WHERE chj.chat_id = c.ROWID),
                   m.cache_roomnames IS NOT NULL
            FROM message m
            JOIN handle h ON h.ROWID = m.handle_id
            LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            LEFT JOIN chat c ON c.ROWID = cmj.chat_id
            LEFT JOIN message_attachment_join maj ON maj.message_id = m.ROWID
            LEFT JOIN attachment a ON a.ROWID = maj.attachment_id
            WHERE m.is_audio_message = 1 AND h.id IN (\(SQLiteDatabase.placeholders(count: handles.count)))
            ORDER BY m.date DESC
            LIMIT 5
            """,
            handles.map { .text($0) }
        )
        lines.append("newest audio messages from the Tracked Contact handles: \(rows.count)")
        var audioAttachments: [AudioAttachment] = []
        for row in rows {
            let guid = row[0].text ?? "?"
            let rawDate = row[3].integer ?? 0
            let sentAt = MessagesDatabaseReader.date(fromAppleNanoseconds: rawDate)
            let path = row[5].text.map { MessagesDatabaseReader.expandingTilde($0, homeDirectory: homeDirectory) }
            lines.append("""
                - guid \(guid), handle \(row[1].text ?? "?"), is_from_me \(row[2].integer ?? -1), \
                raw date \(rawDate) (as ns: \(sentAt)), chat style \(row[4].integer.map(String.init) ?? "none"), \
                chat members \(row[9].integer ?? 0), cache_roomnames set \(row[10].integer ?? -1)
                  attachment uti \(row[6].text ?? "none"), mime \(row[7].text ?? "none"), \
                name \(row[8].text ?? "none"), file exists \(path.map { FileManager.default.fileExists(atPath: $0) } ?? false)
                  path \(path ?? "none")
                """)
            if let path { audioAttachments.append(AudioAttachment(guid: guid, path: path)) }
        }
        return (lines, audioAttachments)
    }

    /// Keeps the format of a Handle visible but hides most of it: digits become 9, letters become x,
    /// except the last 3 characters.
    private static func masked(_ handle: String) -> String {
        let visible = handle.suffix(3)
        let hidden = handle.dropLast(3).map { $0.isNumber ? "9" : $0.isLetter ? "x" : $0 }
        return String(hidden) + visible
    }
}
