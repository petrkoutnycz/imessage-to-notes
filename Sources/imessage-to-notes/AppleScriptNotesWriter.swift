import Foundation
import ImessageToNotesCore

/// The Notes Writer: creates Message Notes in the iCloud account of the Notes app through AppleScript.
/// It needs the macOS Automation permission for Notes.
final class AppleScriptNotesWriter: NotesWriter {
    static let accountName = "iCloud"

    func createMessageNote(inFolder notesFolder: String, title: String, htmlBody: String) async throws -> String {
        // Notes takes the note title from the first line of the body.
        let body = "<div><h1>\(HTML.escape(title))</h1></div>" + htmlBody
        let source = """
            tell application "Notes"
                set notesFolder to folder \(AppleScript.literal(notesFolder)) of account \(AppleScript.literal(Self.accountName))
                set newNote to make new note at notesFolder with properties {body:\(AppleScript.literal(body))}
                return id of newNote
            end tell
            """
        let noteID = try await MainActor.run { try AppleScript.run(source).stringValue }
        guard let noteID, !noteID.isEmpty else {
            throw AdapterError("Notes returned no note ID")
        }
        return noteID
    }

    /// Shows the Message Note with `noteID` in the Notes app, in front of other apps.
    func openMessageNote(id noteID: String) async throws {
        let source = """
            tell application "Notes"
                show note id \(AppleScript.literal(noteID))
                activate
            end tell
            """
        try await MainActor.run { _ = try AppleScript.run(source) }
    }
}

enum AppleScript {
    @MainActor
    static func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw AdapterError("Cannot compile AppleScript")
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = errorInfo[NSAppleScript.errorNumber] ?? "?"
            let message = errorInfo[NSAppleScript.errorMessage] ?? "unknown error"
            throw AdapterError("AppleScript error \(number): \(message)")
        }
        return result
    }

    /// An AppleScript string literal.
    static func literal(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
