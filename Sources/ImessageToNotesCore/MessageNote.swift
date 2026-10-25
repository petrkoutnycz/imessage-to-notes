import Foundation

/// The title and HTML body of a Message Note.
enum MessageNote {
    /// `<Tracked Contact name> – <YYYY-MM-DD HH:MM>` in local time.
    static func title(trackedContactName: String, sentAt: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(trackedContactName) – \(formatter.string(from: sentAt))"
    }

    /// The Summary, then an "Úkoly" list for Action Items. Never the Transcript.
    static func body(summary: Summary) -> String {
        var html = "<div>\(HTML.escape(summary.text))</div>"
        if !summary.actionItems.isEmpty {
            html += "<div><br></div><div><b>Úkoly</b></div>"
            html += "<ul>" + summary.actionItems.map { "<li>\(HTML.escape($0))</li>" }.joined() + "</ul>"
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
