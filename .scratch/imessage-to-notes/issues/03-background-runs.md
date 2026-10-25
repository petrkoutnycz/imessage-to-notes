# 03: Background runs

**What to build:** I do not start the tool by hand anymore. It starts by itself at login and every 5 minutes after that, so a Message Note appears about 5 minutes after a Voice Message arrives. Only one run is active at a time, so a slow run and the next scheduled run never create duplicate Message Notes.

This ticket adds the per-user launchd agent and the run lock. See the spec at `.scratch/imessage-to-notes/spec.md` and ADR 0002.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** ready-for-agent

- [ ] A per-user launchd agent starts the tool at login and every 5 minutes.
- [ ] The agent runs in the user session, so Notes and notifications work.
- [ ] Each start does one run and exits.
- [ ] Each run takes a file lock first. If another run holds the lock, the new run exits at once and creates nothing.
- [ ] A "run once" test makes sure that a run with the lock held by another run creates no Message Note.
- [ ] After the agent is loaded, a real Voice Message produces a Message Note with no manual start.
