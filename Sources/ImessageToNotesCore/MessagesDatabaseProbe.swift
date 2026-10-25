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

        guard !handles.isEmpty else { return (lines, []) }
        let rows = try database.query(
            """
            SELECT m.guid, h.id, m.is_from_me, m.date, c.style, a.filename, a.uti, a.mime_type, a.transfer_name,
                   (SELECT COUNT(*) FROM chat_handle_join chj WHERE chj.chat_id = c.ROWID)
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
                chat members \(row[9].integer ?? 0)
                  attachment uti \(row[6].text ?? "none"), mime \(row[7].text ?? "none"), \
                name \(row[8].text ?? "none"), file exists \(path.map { FileManager.default.fileExists(atPath: $0) } ?? false)
                  path \(path ?? "none")
                """)
            if let path { audioAttachments.append(AudioAttachment(guid: guid, path: path)) }
        }
        return (lines, audioAttachments)
    }
}
