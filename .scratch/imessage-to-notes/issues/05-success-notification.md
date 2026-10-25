# 05: Success notification

**What to build:** I get a macOS notification for each new Message Note. It says "Nová hlasová zpráva od <name> zpracována" with the time. The notification never shows the Summary, so nothing private appears on my lock screen or during screen sharing. A click on the notification opens that Message Note in Notes.

This ticket adds the Notifier adapter and the "open note by ID" action of the Notes Writer. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** ready-for-agent

- [ ] Each new Message Note produces one notification with the Tracked Contact name and the time.
- [ ] The notification contains no Summary or Transcript text.
- [ ] The notification carries the Message Note ID.
- [ ] A click on the notification starts the app, and the app opens that Message Note in Notes.
- [ ] A "run once" test with fake adapters makes sure that one Message Note produces one notification with the right text.
- [ ] A manual run makes sure that the real notification appears and that the click opens the right Message Note.
