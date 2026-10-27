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
        // A State Store from before the retry rule has only the columns above.
        let columns = Set(try database.query("SELECT name FROM pragma_table_info('voice_messages')").compactMap { $0[0].text })
        for (name, definition) in Self.retryColumns where !columns.contains(name) {
            try database.execute("ALTER TABLE voice_messages ADD COLUMN \(name) \(definition)")
        }
    }

    private static let retryColumns = [
        ("failed_attempts", "INTEGER NOT NULL DEFAULT 0"),
        ("last_error", "TEXT"),
        ("transcript", "TEXT"),
        ("audio_duration", "REAL"),
    ]

    public func record(for guid: String) throws -> VoiceMessageRecord? {
        let rows = try database.query(
            """
            SELECT status, first_seen_at, note_id, failed_attempts, last_error, transcript, audio_duration
            FROM voice_messages WHERE guid = ?
            """,
            [.text(guid)]
        )
        guard let row = rows.first else { return nil }
        guard let statusText = row[0].text, let status = VoiceMessageStatus(rawValue: statusText),
              let firstSeenAt = row[1].real, let failedAttempts = row[3].integer
        else {
            throw SQLiteError(description: "Bad State Store row for \(guid)")
        }
        let pendingTranscript = row[5].text.map { transcript in
            TranscribedAudio(transcript: transcript, audioDuration: row[6].real ?? 0)
        }
        return VoiceMessageRecord(
            guid: guid,
            status: status,
            noteID: row[2].text,
            firstSeenAt: Date(timeIntervalSince1970: firstSeenAt),
            failedAttempts: Int(failedAttempts),
            lastError: row[4].text,
            pendingTranscript: pendingTranscript
        )
    }

    public func storeTranscript(_ transcribed: TranscribedAudio, guid: String, firstSeenAt: Date) throws {
        try database.query(
            """
            INSERT INTO voice_messages (guid, status, first_seen_at, transcript, audio_duration) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(guid) DO UPDATE SET transcript = excluded.transcript, audio_duration = excluded.audio_duration
            """,
            [
                .text(guid), .text(VoiceMessageStatus.pending.rawValue), .real(firstSeenAt.timeIntervalSince1970),
                .text(transcribed.transcript), .real(transcribed.audioDuration),
            ]
        )
    }

    public func recordFailure(guid: String, error: String, firstSeenAt: Date) throws {
        try database.query(
            """
            INSERT INTO voice_messages (guid, status, first_seen_at, failed_attempts, last_error) VALUES (?, ?, ?, 1, ?)
            ON CONFLICT(guid) DO UPDATE SET failed_attempts = failed_attempts + 1, last_error = excluded.last_error
            """,
            [.text(guid), .text(VoiceMessageStatus.pending.rawValue), .real(firstSeenAt.timeIntervalSince1970), .text(error)]
        )
    }

    public func markDone(guid: String, noteID: String, firstSeenAt: Date) throws {
        try mark(guid: guid, status: .done, noteID: noteID, firstSeenAt: firstSeenAt)
    }

    public func markFallback(guid: String, noteID: String, firstSeenAt: Date) throws {
        try mark(guid: guid, status: .fallback, noteID: noteID, firstSeenAt: firstSeenAt)
    }

    /// Records the Message Note of the Voice Message and erases its pending Transcript.
    private func mark(guid: String, status: VoiceMessageStatus, noteID: String, firstSeenAt: Date) throws {
        try database.query(
            """
            INSERT INTO voice_messages (guid, status, first_seen_at, note_id) VALUES (?, ?, ?, ?)
            ON CONFLICT(guid) DO UPDATE SET status = excluded.status, note_id = excluded.note_id,
                transcript = NULL, audio_duration = NULL
            """,
            [.text(guid), .text(status.rawValue), .real(firstSeenAt.timeIntervalSince1970), .text(noteID)]
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
