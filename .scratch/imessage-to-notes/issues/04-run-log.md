# 04: Run log

**What to build:** I can open a log file and find out what happened to any Voice Message in each run. The log never contains Transcript or Summary text, so private content does not stay in a plain file. Old log files disappear after 30 days.

This ticket adds the Log adapter and the log entries for the existing steps. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** ready-for-agent

- [ ] The tool writes daily text files in its own folder under the user Logs folder.
- [ ] Each entry holds the Voice Message GUID, timestamps, audio duration, the Tracked Contact name, the step status and error details.
- [ ] No entry holds Transcript or Summary text.
- [ ] Each run deletes log files older than 30 days.
- [ ] A "run once" test with fake adapters makes sure that the Transcript and the Summary never appear in the log.
- [ ] A test with a fake clock makes sure that the run deletes log files older than 30 days and keeps newer ones.
