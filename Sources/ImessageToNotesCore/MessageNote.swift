import Foundation

/// The title and HTML body of a Message Note, and the notification about it.
enum MessageNote {
    /// `<Tracked Contact name> – <YYYY-MM-DD HH:MM>` in local time.
    static func title(trackedContactName: String, sentAt: Date, timeZone: TimeZone) -> String {
        "\(trackedContactName) – \(localTime(sentAt, timeZone: timeZone))"
    }

    /// The Tracked Contact name and the sent time of the Voice Message. Never the Summary or the Transcript.
    static func notification(trackedContactName: String, sentAt: Date, noteID: String, timeZone: TimeZone) -> UserNotification {
        UserNotification(
            title: "Nová hlasová zpráva od \(trackedContactName) zpracována",
            body: localTime(sentAt, timeZone: timeZone),
            click: .openMessageNote(noteID: noteID)
        )
    }

    /// The Tracked Contact name, the failed step and the sent time. Never the Transcript.
    static func fallbackNotification(
        _ fallback: Fallback,
        trackedContactName: String,
        sentAt: Date,
        noteID: String,
        timeZone: TimeZone
    ) -> UserNotification {
        let title = switch fallback {
        case .summaryFailed: "Shrnutí hlasové zprávy od \(trackedContactName) selhalo"
        case .transcriptionFailed: "Přepis hlasové zprávy od \(trackedContactName) selhal"
        case .audioFileMissing: "Zvukový soubor hlasové zprávy od \(trackedContactName) chybí"
        }
        return UserNotification(title: title, body: localTime(sentAt, timeZone: timeZone), click: .openMessageNote(noteID: noteID))
    }

    /// `YYYY-MM-DD HH:MM` in local time.
    private static func localTime(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// The Summary, then an "Úkoly" list for Action Items. A "Přepis" section with `transcript` comes last,
    /// if `transcript` is not nil.
    static func body(summary: Summary, transcript: String?) -> String {
        var html = "<div>\(HTML.escape(summary.text))</div>"
        if !summary.actionItems.isEmpty {
            html += "<div><br></div><div><b>Úkoly</b></div>"
            html += "<ul>" + summary.actionItems.map { "<li>\(HTML.escape($0))</li>" }.joined() + "</ul>"
        }
        if let transcript {
            html += "<div><br></div><div><b>Přepis</b></div>"
            html += "<div>\(HTML.escape(transcript))</div>"
        }
        return html
    }

    /// The body of a fallback Message Note. Only a failed Summary leaves a Transcript to show.
    static func fallbackBody(_ fallback: Fallback) -> String {
        switch fallback {
        case .summaryFailed(let transcript):
            "<div>Shrnutí se nepodařilo vytvořit</div><div><br></div><div>\(HTML.escape(transcript))</div>"
        case .transcriptionFailed:
            "<div>Přepis se nepodařilo vytvořit, takže chybí i shrnutí. Hlasová zpráva je v aplikaci Zprávy.</div>"
        case .audioFileMissing:
            "<div>Zvukový soubor hlasové zprávy na tomto Macu chybí, takže se nepodařilo vytvořit přepis ani shrnutí.</div>"
        }
    }
}

extension UserNotification {
    /// The notification about a missing Notes Folder. A click opens Notes, where the user creates the folder.
    static func notesFolderMissing(_ notesFolder: String) -> UserNotification {
        UserNotification(
            title: "Složka pro hlasové zprávy chybí",
            body: "V Poznámkách v účtu iCloud chybí složka „\(notesFolder)“. Vytvořte ji.",
            click: .openNotes
        )
    }
}

/// Why a Voice Message gets a fallback Message Note.
enum Fallback {
    case summaryFailed(transcript: String)
    case transcriptionFailed
    case audioFileMissing
}

public enum HTML {
    public static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
