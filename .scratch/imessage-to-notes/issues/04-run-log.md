# 04: Run log

**What to build:** I can open a log file and find out what happened to any Voice Message in each run. The log never contains Transcript or Summary text, so private content does not stay in a plain file. Old log files disappear after 30 days.

This ticket adds the Log adapter and the log entries for the existing steps. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** done

- [x] The tool writes daily text files in its own folder under the user Logs folder.
- [x] Each entry holds the Voice Message GUID, timestamps, audio duration, the Tracked Contact name, the step status and error details.
- [x] No entry holds Transcript or Summary text.
- [x] Each run deletes log files older than 30 days.
- [x] A "run once" test with fake adapters makes sure that the Transcript and the Summary never appear in the log.
- [x] A test with a fake clock makes sure that the run deletes log files older than 30 days and keeps newer ones.

## Comments

Ticket 03 sends the standard output and the standard error of the launchd agent to `~/Library/Logs/imessage-to-notes/agent.log`. This file is not a daily file, and the 30-day deletion rule never deletes it, because each run writes to it. It also gets the raw error text of the real adapters. An AppleScript error from Notes can quote values from the script, which can include the Summary. This ticket must remove `agent.log` from the agent definition in `scripts/load-agent.sh`, or make it follow the log rules.

The Log adapter is `FileLog` in `Sources/ImessageToNotesCore/Log.swift`. It writes `yyyy-MM-dd.log` files in `~/Library/Logs/imessage-to-notes` with mode 0600. Each run that gets the lock deletes the files of the days before the day 30 days ago. A failed deletion gets a `log cleanup failed` entry, and the run continues. A failed log write stops the run.

A log entry has no field for Transcript or Summary text. The error details of a failed step can quote private text, for example in an AppleScript error. The run replaces each run of 10 or more characters that also occurs in the Transcript, the Summary, an Action Item or the HTML body with `[redacted]`. A quote that the AppleScript or HTML escaping splits into pieces under 10 characters is not caught. The Summarizer step knows only the Transcript, so it cannot redact a quoted Summary.

The Transcriber now returns the audio duration with the Transcript. The real Transcriber reads it with `AVAudioFile`. A setup failure in the binary, for example a bad configuration file, also gets a `run failed` entry, because launchd keeps no output.

`scripts/load-agent.sh` no longer sends output to `agent.log`, and it deletes an old `agent.log`. Run `scripts/load-agent.sh` again to install the new agent definition. The smoke run in `docs/smoke-run.md` has a new "Run log" section.

For ticket 06: a `run failed` entry holds the raw error text with no redaction. When the State Store keeps the pending Transcript, make sure that its errors cannot quote it.
