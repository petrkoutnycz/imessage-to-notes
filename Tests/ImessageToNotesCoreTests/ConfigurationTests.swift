import Foundation
import Testing
import ImessageToNotesCore

@Test func configurationFileHoldsSeveralTrackedContactsWithSeveralHandles() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("""
        {
          "trackedContacts": [
            { "name": "Jana Nováková", "handles": ["+420 777 123 456", "Jana.Novakova@iCloud.com"] },
            { "name": "Petr Novák", "handles": ["+420602111222", "petr@example.com"] }
          ],
          "notesFolder": "Hlasové zprávy",
          "claudeModel": "claude-sonnet-5-5"
        }
        """.utf8).write(to: url)

    let configuration = try Configuration.load(from: url)

    #expect(configuration.trackedContact(for: "jana.novakova@icloud.com")?.name == "Jana Nováková")
    #expect(configuration.trackedContact(for: "+420777123456")?.name == "Jana Nováková")
    #expect(configuration.trackedContact(for: "petr@example.com")?.name == "Petr Novák")
    #expect(configuration.trackedContact(for: "+420600000000") == nil)
}

@Test func configurationFileSetsBackfillWindowInDaysWithSevenAsDefault() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let withoutWindow = """
        { "trackedContacts": [], "notesFolder": "Hlasové zprávy", "claudeModel": "claude-sonnet-5-5" }
        """
    try Data(withoutWindow.utf8).write(to: url)
    #expect(try Configuration.load(from: url).backfillDays == 7)

    let withWindow = """
        { "trackedContacts": [], "notesFolder": "Hlasové zprávy", "claudeModel": "claude-sonnet-5-5", "backfillDays": 3 }
        """
    try Data(withWindow.utf8).write(to: url)
    #expect(try Configuration.load(from: url).backfillDays == 3)
}

@Test func configurationFileSetsIncludeTranscriptWithFalseAsDefault() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let withoutSetting = """
        { "trackedContacts": [], "notesFolder": "Hlasové zprávy", "claudeModel": "claude-sonnet-5-5" }
        """
    try Data(withoutSetting.utf8).write(to: url)
    #expect(try Configuration.load(from: url).includeTranscript == false)

    let withSetting = """
        { "trackedContacts": [], "notesFolder": "Hlasové zprávy", "claudeModel": "claude-sonnet-5-5", "includeTranscript": true }
        """
    try Data(withSetting.utf8).write(to: url)
    #expect(try Configuration.load(from: url).includeTranscript == true)
}

@Test func configurationFileSetsRetryWindowInHoursWithTwelveAsDefault() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let withoutWindow = """
        { "trackedContacts": [], "notesFolder": "Hlasové zprávy", "claudeModel": "claude-sonnet-5-5" }
        """
    try Data(withoutWindow.utf8).write(to: url)
    #expect(try Configuration.load(from: url).retryHours == 12)

    let withWindow = """
        { "trackedContacts": [], "notesFolder": "Hlasové zprávy", "claudeModel": "claude-sonnet-5-5", "retryHours": 2 }
        """
    try Data(withWindow.utf8).write(to: url)
    #expect(try Configuration.load(from: url).retryHours == 2)
}
