# 10: First name in the Summary

**What to build:** The Summary and the Action Items call the Tracked Contact by their first name. Today they say "mluvčí" or "odesílatel", which feels impersonal. The Summarizer gets the whole Tracked Contact name from the configuration with the Transcript. Claude finds the first name in it. If the name has no clear first name, for example "Mamka", Claude uses the name as it is. The Summary does not mention the listener. For example: "Jana připomíná, že zítra v 10 přijde technik."

This change sends the Tracked Contact name to the Claude API. See ADR 0003 and user stories 23 and 44 in the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] The Summarizer gets the Transcript and the name of the Tracked Contact who sent the Voice Message.
- [ ] The Claude request holds the whole Tracked Contact name with the Transcript. It holds no Handle.
- [ ] The prompt tells Claude to find the first name in the name. If no clear first name exists, Claude uses the whole name.
- [ ] The Summary and each Action Item call the speaker by that first name, in the correct Czech case and gender.
- [ ] The prompt no longer asks for the speaker in an anonymous third person, and it does not mention the listener.
- [ ] Message Notes that exist do not change. Fallback Message Notes, notifications and the log do not change.
- [ ] A "run once" test with two Tracked Contacts makes sure that each Message Note body holds the name of the correct Tracked Contact. The fake Summarizer puts the name it gets into the Summary.
- [ ] A manual smoke run with one real Voice Message shows the first name in the Summary.

## Comments
