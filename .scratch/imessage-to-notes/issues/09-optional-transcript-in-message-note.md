# 09: Optional Transcript in the Message Note

**What to build:** I can choose to keep the full Transcript in each new Message Note. A setting in the configuration file controls this, and by default the Message Note holds no Transcript. If I turn the setting on, the Transcript comes last in the Message Note, after the Summary and any Action Items. The fallback Message Notes do not change.

This ticket adds the `includeTranscript` setting and the "Přepis" section of the normal body. See user story 43 in the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] The configuration has a boolean `includeTranscript`. If the file leaves it out, its value is false.
- [x] `App/config.example.json` holds `"includeTranscript": false`.
- [x] If `includeTranscript` is false, the normal Message Note body holds no Transcript, as before.
- [x] If `includeTranscript` is true, the normal body ends with a bold "Přepis" heading and the Transcript. The Transcript is one escaped paragraph after the "Úkoly" list.
- [x] At the creation of each Message Note, the tool reads the current setting. It never changes an existing Message Note.
- [x] The setting does not change the fallback bodies.
- [x] Notifications still show only the Tracked Contact name and the time, and the log still holds no Transcript text.
- [x] "Run once" tests cover the normal body with the setting off and with the setting on.

## Comments

The configuration reads `includeTranscript`, with false as the default. If the setting is true, the normal body ends with `<div><br></div><div><b>Přepis</b></div><div>…</div>`, with the escaped Transcript. Each run loads the configuration again, so a change of the setting applies to the next new Message Note only. The fallback bodies do not exist yet, and the setting changes only the normal body. "Run once" tests cover the setting off and on, a change of the setting between runs, and a notification and log with no Transcript when the setting is on. A Transcript with line breaks stays in one `<div>`. No test makes sure how Notes shows those line breaks.
