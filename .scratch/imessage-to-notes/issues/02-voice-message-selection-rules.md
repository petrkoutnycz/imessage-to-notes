# 02: Voice Message selection rules

**What to build:** The tool processes every Voice Message that a Tracked Contact sends me in a Direct Chat, and nothing else. It recognizes the contact from any of their Handles. It ignores group chats, text messages, videos, attached audio files and my own Voice Messages. On the first run, it goes back 7 days. Later runs pick up every Voice Message after that start that is not done, so a run after sleep catches up.

This ticket completes the Messages Reader and the selection rules in the "run once" core. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** done

- [x] The configuration accepts a list of Tracked Contacts, each with a name and several Handles.
- [x] The tool matches phone numbers after it removes spaces and punctuation, in international format with the country code.
- [x] The tool matches email addresses without regard to letter case.
- [x] Group chats, messages from me and messages that are not Voice Messages produce no Message Note.
- [x] The State Store records the first-run time. The backfill start is that time minus 7 days, and it never moves.
- [x] One run processes every candidate that is not done, in order of arrival.
- [x] Fixture tests run the Messages Reader against small SQLite files that copy the parts of the real schema that the reader uses.
- [x] The fixture tests cover audio versus other messages, from-me messages, one-to-one versus group chats, phone and email Handles, and Apple epoch date filtering.
- [x] "Run once" tests with fake adapters cover the backfill start and the processing of several pending Voice Messages.

## Comments

2026-10-25: Implemented with tests at the two seams of the spec: the Messages Reader against SQLite fixture files, and "run once" with fake adapters. Decisions, recorded in the spec:

- A Voice Message with no chat link counts as a Direct Chat message. Only a link to a chat with a style other than 45 excludes a Voice Message. The risk is that a group chat Voice Message with no chat link produces a Message Note.
- The backfill window is fixed at 7 days in the code and is not in the configuration. A configurable window moves the backfill start, and the backfill start must never move.
- For a Handle with `@`, letter case does not matter. For any other Handle, only the digits count.
- If a message has more than one attachment row, the reader uses the first attachment.

Open until ticket 06: a failed step stops the run, so one failed Voice Message blocks the later ones on every run. No manual run on the real Messages database has happened yet with these rules. The first real run records the first-run time and processes the Voice Messages of the 7 days before it. The Voice Message that ticket 01 processed stays done.
