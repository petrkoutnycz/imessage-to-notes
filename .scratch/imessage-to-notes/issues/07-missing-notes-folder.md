# 07: Missing Notes Folder

**What to build:** The tool does nothing with my Voice Messages while my Notes Folder is missing from my iCloud account. It never creates a folder that I did not ask for. It logs the error and sends me a notification, so I can fix the configuration. The notification comes at most once every 24 hours, so one problem does not flood my screen. After I create the folder, the next run processes all waiting Voice Messages.

See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 04 (Run log), 05 (Success notification).

**Status:** ready-for-agent

- [ ] Each run makes sure that the Notes Folder exists in the iCloud account before it processes any Voice Message.
- [ ] If the Notes Folder is missing, the run stops, creates no Message Note and creates no folder.
- [ ] The run logs the missing Notes Folder.
- [ ] The run sends a notification about the missing Notes Folder at most once every 24 hours.
- [ ] After the Notes Folder exists again, the next run processes the waiting Voice Messages.
- [ ] "Run once" tests with a fake clock cover the stop, the 24-hour notification limit and the recovery.
