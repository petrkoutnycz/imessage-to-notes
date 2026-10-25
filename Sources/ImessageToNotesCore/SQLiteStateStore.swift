import Foundation

/// The State Store: a small SQLite database in the tool's Application Support folder.
public final class SQLiteStateStore: StateStore {
    private let database: SQLiteDatabase

    public init(path: String) throws {
        let directory = URL(filePath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        database = try SQLiteDatabase(path: path, mode: .readWriteCreate)
        try database.execute("""
            CREATE TABLE IF NOT EXISTS voice_messages (
                guid TEXT PRIMARY KEY,
                status TEXT NOT NULL,
                first_seen_at REAL NOT NULL,
                note_id TEXT
            );
            CREATE TABLE IF NOT EXISTS first_run (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                first_run_at REAL NOT NULL
            );
            """)
    }

    public func record(for guid: String) throws -> VoiceMessageRecord? {
        let rows = try database.query(
            "SELECT status, first_seen_at, note_id FROM voice_messages WHERE guid = ?",
            [.text(guid)]
        )
        guard let row = rows.first else { return nil }
        guard let statusText = row[0].text, let status = VoiceMessageStatus(rawValue: statusText),
              let firstSeenAt = row[1].real
        else {
            throw SQLiteError(description: "Bad State Store row for \(guid)")
        }
        return VoiceMessageRecord(
            guid: guid,
            status: status,
            noteID: row[2].text,
            firstSeenAt: Date(timeIntervalSince1970: firstSeenAt)
        )
    }

    public func markDone(guid: String, noteID: String, firstSeenAt: Date) throws {
        try database.query(
            """
            INSERT INTO voice_messages (guid, status, first_seen_at, note_id) VALUES (?, ?, ?, ?)
            ON CONFLICT(guid) DO UPDATE SET status = excluded.status, note_id = excluded.note_id
            """,
            [.text(guid), .text(VoiceMessageStatus.done.rawValue), .real(firstSeenAt.timeIntervalSince1970), .text(noteID)]
        )
    }

    public func firstRunAt(recordingIfMissing now: Date) throws -> Date {
        try database.query(
            "INSERT INTO first_run (id, first_run_at) VALUES (1, ?) ON CONFLICT(id) DO NOTHING",
            [.real(now.timeIntervalSince1970)]
        )
        let rows = try database.query("SELECT first_run_at FROM first_run WHERE id = 1")
        guard let row = rows.first, let firstRunAt = row[0].real else {
            throw SQLiteError(description: "The State Store has no first-run time")
        }
        return Date(timeIntervalSince1970: firstRunAt)
    }
}
