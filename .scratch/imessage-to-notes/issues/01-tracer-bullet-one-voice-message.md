# 01: Tracer bullet: one real Voice Message becomes one Message Note

**What to build:** I start the tool by hand. It finds the newest Voice Message from my one Tracked Contact and creates one Message Note for it in my Notes Folder in iCloud. The Message Note has the Tracked Contact name and the date and time in its title. Its body has the Czech Summary and any Action Items, and no Transcript. If I start the tool again, it creates nothing new.

This ticket builds the thinnest complete path through every part of the tool. The parts are the configuration file, the Messages Reader, the Transcriber, the Summarizer, the Notes Writer and the State Store. The Transcriber uses WhisperKit with Whisper large-v3, with the language fixed to Czech. The Summarizer uses Claude `claude-sonnet-5-5`, with the API key from the Keychain. It also builds the "run once" core with fake adapters and its first tests. See the spec at `.scratch/imessage-to-notes/spec.md`, ADR 0001 and ADR 0002.

Human prerequisites before an agent starts: full Xcode is installed, and an Apple Development certificate exists. During the ticket, the human grants Full Disk Access and the Notes Automation permission to the app. The human also puts the API key into the Keychain and creates the Notes Folder.

**Blocked by:** None (can start immediately, after the human prerequisites).

**Status:** done

- [x] The tool is one Swift binary in an app bundle, signed with the Apple Development certificate.
- [x] A rebuild keeps Full Disk Access, with no new grant.
- [x] The configuration file holds one Tracked Contact (name plus Handles) and the Notes Folder name.
- [x] The tool opens the Messages database read-only.
- [x] The real database matches the markers that the spec expects (audio flag, from-me flag, chat style, attachment join, Apple epoch dates). Any difference is written into the spec.
- [x] The audio file of a real Voice Message decodes, and WhisperKit transcribes it in Czech.
- [x] The Summarizer returns a structured response: a Summary of 2 to 4 Czech sentences and a list of Action Items, which can be empty.
- [x] The Notes Writer creates the Message Note in the Notes Folder of the iCloud account and returns its note ID.
- [x] The Message Note title is `<Tracked Contact name> – <YYYY-MM-DD HH:MM>` in local time.
- [x] The body has the Summary and no Transcript. An "Úkoly" list follows the Summary only for a Voice Message with Action Items.
- [x] The State Store records the Voice Message as done with its Message Note ID. A second run creates no Message Note.
- [x] No Transcript stays on disk after the Message Note exists.
- [x] Tests call "run once" with fake adapters and a fake clock. They cover the happy path and the rule that a done Voice Message never gets a second Message Note.
- [x] A manual smoke run with one real Voice Message produces the expected Message Note on the Mac and on the iPhone.

## Comments

2026-10-25: The `sample` command ran the real Transcriber on a saved Voice Message (`Audio Message.caf`). The file is CAF with Opus audio, 1 channel, 24 kHz, 76 seconds. WhisperKit large-v3 with the language fixed to Czech decoded it and returned a coherent Czech Transcript, with a few recognition errors. The model download is 2.9 GB. This test did not use the Messages database path, so the probe on the real database is still open.

2026-10-25: A second `sample` run also called the real Summarizer (`claude-sonnet-5-5`, structured response, API key from the Keychain). It returned a Summary of 3 Czech sentences and 2 Action Items. The Summary calls the speaker "Mluvčí", because only the Transcript goes to Claude and the Transcript has no name.

2026-10-25: Manual smoke run with the signed app, started through `open`. The probe read the Messages database with Full Disk Access, and it read the database again after a rebuild with no new grant. The database markers match the spec, with one difference: many Voice Messages have no chat link. The spec now records this as a question for ticket 02. A run created a Message Note for Voice Message `4DE4BB60-5D62-4051-8BA0-30CA42FD979F` in the Notes Folder in iCloud. The State Store recorded it as done with the note ID, and a second run created no Message Note. The first configured phone Handle was wrong. The user corrected it in `config.json`.

2026-10-25: The user confirmed that the Message Note appears in the Notes Folder on the iPhone. All checklist items are done.
