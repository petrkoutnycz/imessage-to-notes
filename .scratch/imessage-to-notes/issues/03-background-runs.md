# 03: Background runs

**What to build:** I do not start the tool by hand anymore. It starts by itself at login and every 5 minutes after that, so a Message Note appears about 5 minutes after a Voice Message arrives. Only one run is active at a time, so a slow run and the next scheduled run never create duplicate Message Notes.

This ticket adds the per-user launchd agent and the run lock. See the spec at `.scratch/imessage-to-notes/spec.md` and ADR 0002.

**Blocked by:** 01 (Tracer bullet: one real Voice Message becomes one Message Note).

**Status:** done

- [x] A per-user launchd agent starts the tool at login and every 5 minutes.
- [x] The agent runs in the user session, so Notes and notifications work.
- [x] Each start does one run and exits.
- [x] Each run takes a file lock first. If another run holds the lock, the new run exits at once and creates nothing.
- [x] A "run once" test makes sure that a run with the lock held by another run creates no Message Note.
- [x] After the agent is loaded, a real Voice Message produces a Message Note with no manual start.

## Comments

The agent, the run lock and the tests are in place. `scripts/load-agent.sh` installs the app in `~/Applications` and loads the agent, and `scripts/unload-agent.sh` unloads it. The coding agent had no permission to load the launchd agent on this Mac. The last item needs a human: run `scripts/load-agent.sh`, then make sure that a real Voice Message produces a Message Note with no manual start. See "Background runs" in `docs/smoke-run.md`.

The manual check on 2026-10-25 made sure that the loaded agent works. The launchd agent started a run at 21:33 with no manual start. The run created a Message Note for each of two Voice Messages that arrived at 21:31 and 21:32.
