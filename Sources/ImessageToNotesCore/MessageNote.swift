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
            noteID: noteID
        )
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
