import Foundation
import ImessageToNotesCore
import UserNotifications

/// Opens the Message Note of a clicked notification in Notes.
/// macOS hands a click to the app process that runs, or it starts the app with no arguments.
@MainActor
final class NotificationClickHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationClickHandler()

    /// Runs after the handler tries to open a Message Note.
    var onClickHandled: (() -> Void)?
    /// True from the first click on, also while Notes opens the Message Note.
    private(set) var clickReceived = false

    /// Makes this handler the delegate of the notification center. The center keeps no strong reference.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        // A notification about a missing Notes Folder has no Message Note to open.
        let noteID = response.notification.request.content.userInfo[UserNotificationNotifier.noteIDKey] as? String
        await open(noteID)
    }

    /// Shows the banner also when macOS counts this app as the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func open(_ noteID: String?) async {
        clickReceived = true
        if let noteID {
            await openMessageNote(noteID)
        }
        onClickHandled?()
    }

    private func openMessageNote(_ noteID: String) async {
        do {
            try await AppleScriptNotesWriter().openMessageNote(id: noteID)
        } catch {
            // The process has no visible output, so the log is the only record of this failure.
            try? FileLog(directory: Paths.logs).write(LogEntry(
                time: Date(),
                event: .messageNoteOpenFailed(noteID: noteID, error: String(describing: error))
            ))
        }
    }
}
