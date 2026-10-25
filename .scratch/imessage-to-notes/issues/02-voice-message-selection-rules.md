# 02: Voice Message selection rules

**What to build:** The tool processes every Voice Message that a Tracked Contact sends me in a Direct Chat, and nothing else. It recognizes the contact from any of their Handles. It ignores group chats, text messages, videos, attached audio files and my own Voice Messages. On the first run, it goes back 7 days. Later runs pick up every Voice Message after that start that is not done, so a run after sleep catches up.

This ticket completes the Messages Reader and the selection rules in the "run once" core. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** ready-for-agent

- [ ] The configuration accepts a list of Tracked Contacts, each with a name and several Handles.
- [ ] The tool matches phone numbers after it removes spaces and punctuation, in international format with the country code.
- [ ] The tool matches email addresses without regard to letter case.
- [ ] Group chats, messages from me and messages that are not Voice Messages produce no Message Note.
- [ ] The State Store records the first-run time. The backfill start is that time minus 7 days, and it never moves.
- [ ] One run processes every candidate that is not done, in order of arrival.
- [ ] Fixture tests run the Messages Reader against small SQLite files that copy the parts of the real schema that the reader uses.
- [ ] The fixture tests cover audio versus other messages, from-me messages, one-to-one versus group chats, phone and email Handles, and Apple epoch date filtering.
- [ ] "Run once" tests with fake adapters cover the backfill start and the processing of several pending Voice Messages.
