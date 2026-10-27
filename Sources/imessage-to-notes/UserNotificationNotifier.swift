import Foundation
import ImessageToNotesCore
import Synchronization
import UserNotifications

/// The Notifier: macOS user notifications of the app. The first notification asks for the permission.
final class UserNotificationNotifier: Notifier {
    /// The `userInfo` key of the Message Note ID in a notification.
    static let noteIDKey = "noteID"
    /// The `userInfo` key that marks a notification whose click opens the Notes app.
    static let opensNotesKey = "opensNotes"
    /// How long a run waits for an answer to the permission request. A run that waits forever blocks all later runs.
    static let permissionTimeout: TimeInterval = 60

    /// A refused or unanswered permission request. The run asks only once, so that a run with many
    /// Voice Messages does not wait `permissionTimeout` for each of them.
    private var permissionFailure: (any Error)?

    func send(_ notification: UserNotification) async throws {
        if let permissionFailure {
            throw permissionFailure
        }
        let center = UNUserNotificationCenter.current()
        do {
            try await makeSurePermissionIsGranted(center)
        } catch {
            permissionFailure = error
            throw error
        }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        let identifier: String
        switch notification.click {
        case .openMessageNote(let noteID):
            content.userInfo = [Self.noteIDKey: noteID]
            identifier = noteID
        case .openNotes:
            content.userInfo = [Self.opensNotesKey: true]
            identifier = UUID().uuidString
        }
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    private func makeSurePermissionIsGranted(_ center: UNUserNotificationCenter) async throws {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional:
            return
        case .notDetermined:
            guard try await requestPermission(center) else {
                throw AdapterError("Notifications are not allowed for iMessage to Notes")
            }
        default:
            throw AdapterError("Notifications are off for iMessage to Notes in System Settings")
        }
    }

    /// Asks for the permission, and stops to wait after `permissionTimeout`.
    private func requestPermission(_ center: UNUserNotificationCenter) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let answer = SingleAnswer(continuation)
            center.requestAuthorization(options: [.alert]) { granted, error in
                answer.resume(with: error.map { .failure($0) } ?? .success(granted))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.permissionTimeout) {
                let seconds = Int(Self.permissionTimeout)
                answer.resume(with: .failure(AdapterError("No answer to the notification permission request in \(seconds) seconds")))
            }
        }
    }
}

/// A continuation that the first of several answers resumes. Later answers do nothing.
private final class SingleAnswer: Sendable {
    private let continuation: Mutex<CheckedContinuation<Bool, any Error>?>

    init(_ continuation: CheckedContinuation<Bool, any Error>) {
        self.continuation = Mutex(continuation)
    }

    func resume(with result: Result<Bool, any Error>) {
        let continuation = self.continuation.withLock { continuation in
            defer { continuation = nil }
            return continuation
        }
        continuation?.resume(with: result)
    }
}
