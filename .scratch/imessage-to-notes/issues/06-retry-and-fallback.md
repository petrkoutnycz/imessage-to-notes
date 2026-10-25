# 06: Retry and fallback Message Notes

**What to build:** The tool does not lose a Voice Message because of a failed step. It tries again on every run for 12 hours. After 12 hours of failure, it creates a fallback Message Note, logs the fallback and sends me one notification. If the Summary failed, the fallback Message Note holds the line "Shrnutí se nepodařilo vytvořit" and the Transcript. If transcription failed or the audio file is missing, it holds a Czech error notice that names the failed step.

This ticket adds the pending status, the retry rule and the fallback bodies. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 04 (Run log), 05 (Success notification).

**Status:** ready-for-agent

- [ ] A failed step leaves the Voice Message pending in the State Store.
- [ ] The State Store records the first-seen time, the attempt count and the last error.
- [ ] Each run retries every pending Voice Message.
- [ ] After a successful transcription, the pending Transcript stays in the State Store, so a retry does not transcribe again.
- [ ] When the tool creates any Message Note, it erases the stored Transcript.
- [ ] A missing audio file counts as a failed step.
- [ ] If a step still fails 12 hours after the first-seen time, the tool creates the fallback Message Note.
- [ ] The tool then marks the Voice Message as fallback.
- [ ] The fallback for a failed Summary holds "Shrnutí se nepodařilo vytvořit" and the Transcript.
- [ ] The fallback for a failed transcription or a missing audio file holds an error notice and no Transcript.
- [ ] Each fallback Message Note produces one notification. A retry produces no notification.
- [ ] The log records each failed attempt and the fallback, with no Transcript or Summary text.
- [ ] "Run once" tests with a fake clock cover a retry that succeeds and both fallback bodies.
- [ ] Tests also cover the missing audio file and the single fallback notification.
