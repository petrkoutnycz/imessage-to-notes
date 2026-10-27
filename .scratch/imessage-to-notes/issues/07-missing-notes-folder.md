# 07: Missing Notes Folder

**What to build:** The tool does nothing with my Voice Messages while my Notes Folder is missing from my iCloud account. It never creates a folder that I did not ask for. It logs the error and sends me a notification, so I can fix the configuration. The notification comes at most once every 24 hours, so one problem does not flood my screen. After I create the folder, the next run processes all waiting Voice Messages.

See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 04 (Run log), 05 (Success notification).

**Status:** ready-for-human

- [x] Each run makes sure that the Notes Folder exists in the iCloud account before it processes any Voice Message.
- [x] If the Notes Folder is missing, the run stops, creates no Message Note and creates no folder.
- [x] The run logs the missing Notes Folder.
- [x] The run sends a notification about the missing Notes Folder at most once every 24 hours.
- [x] After the Notes Folder exists again, the next run processes the waiting Voice Messages.
- [x] "Run once" tests with a fake clock cover the stop, the 24-hour notification limit and the recovery.
- [ ] A manual run makes sure that the real folder check, the notification and its click work. See "Missing Notes Folder" in `docs/smoke-run.md`.

## Comments

Each run asks the Notes Writer if the Notes Folder exists in the iCloud account. The run asks after it takes the run lock and before it reads any Voice Message. If the folder is missing, the run writes `run stopped: notes folder missing` to the log and stops. It creates no Message Note and no folder. The real Notes Writer uses the AppleScript `exists folder` command, the same command as the probe.

The State Store keeps the time of the last notification about the missing folder in the new table `notes_folder_notification`. A run sends the notification only if 24 hours or more passed since that time. A failed notification gets a `notes folder notification failed` log entry and does not count, so the next run tries again. The 24 hours count from the last notification, also if the folder exists for some time between two problems.

The notification has no Message Note to open. A notification now has a `click` value: `openMessageNote(noteID:)` or `openNotes`. A click on the missing-folder notification brings the Notes app to the front, because the user fixes the problem there. A failed open gets a `notes open failed` log entry.

The first run records the first-run time before the folder check. So a first run that stops for a missing folder still fixes the backfill start, and the run after the user creates the folder processes every waiting Voice Message.

The manual run on 2026-10-27 made sure that the real folder check works. The user renamed the Notes Folder, and the notification appeared. The rest of the run behaved as expected. That run had the earlier click, which opened nothing. The click that opens Notes still needs a manual check. See "Missing Notes Folder" in `docs/smoke-run.md`.

A failure of the folder check itself, for example a missing Automation permission for Notes, ends the run with `run failed` and sends no notification. This ticket does not cover that case.
