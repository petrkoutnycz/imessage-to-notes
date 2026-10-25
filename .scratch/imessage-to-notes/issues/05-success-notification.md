# 05: Success notification

**What to build:** I get a macOS notification for each new Message Note. It says "Nová hlasová zpráva od <name> zpracována" with the time. The notification never shows the Summary, so nothing private appears on my lock screen or during screen sharing. A click on the notification opens that Message Note in Notes.

This ticket adds the Notifier adapter and the "open note by ID" action of the Notes Writer. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** ready-for-human

- [x] Each new Message Note produces one notification with the Tracked Contact name and the time.
- [x] The notification contains no Summary or Transcript text.
- [x] The notification carries the Message Note ID.
- [x] A click on the notification starts the app, and the app opens that Message Note in Notes.
- [x] A "run once" test with fake adapters makes sure that one Message Note produces one notification with the right text.
- [ ] A manual run makes sure that the real notification appears and that the click opens the right Message Note.

## Comments

The core builds the notification text, and `runOnce` sends one notification after the State Store marks the Voice Message done. The title is "Nová hlasová zpráva od <name> zpracována", and the text is the sent time in the format of the Message Note title. The notification carries the Message Note ID in its `userInfo`. A failed notification gets a `status=failed step=notify` log entry, and the run goes on, because the Message Note exists. A sent notification gets a `status=notified` entry.

The real Notifier is `UserNotificationNotifier`. If the permission is not determined, it asks for the permission and waits at most 60 seconds, because a run that waits forever blocks all later runs. After a refusal or a timeout, the Notifier does not ask again in the same run. The Notes Writer has a new action that opens a Message Note by ID with the AppleScript `show` command.

A click goes to `NotificationClickHandler`. If the app does not run, macOS starts it with no arguments. The app then waits up to 30 seconds for the click and quits. A start with no arguments no longer does a run. The launchd agent passes `run`, so background runs do not change. A failed open gets a `message note open failed` log entry.

The last item needs a human, because it needs a real Voice Message and a click. See "Notifications" in `docs/smoke-run.md`. If the click does not reach the app, the cause can be that macOS delivers the click before the delegate is set. In that case, look at the log and at the Console app for `usernoted` messages.
