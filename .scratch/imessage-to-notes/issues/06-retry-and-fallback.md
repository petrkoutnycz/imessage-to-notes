# 06: Retry and fallback Message Notes

**What to build:** The tool does not lose a Voice Message because of a failed step. It tries again on every run for 12 hours. After 12 hours of failure, it creates a fallback Message Note, logs the fallback and sends me one notification. If the Summary failed, the fallback Message Note holds the line "Shrnutí se nepodařilo vytvořit" and the Transcript. If transcription failed or the audio file is missing, it holds a Czech error notice that names the failed step.

This ticket adds the pending status, the retry rule and the fallback bodies. See the spec at `.scratch/imessage-to-notes/spec.md`.

**Blocked by:** 04 (Run log), 05 (Success notification).

**Status:** done

- [x] A failed step leaves the Voice Message pending in the State Store.
- [x] The State Store records the first-seen time, the attempt count and the last error.
- [x] Each run retries every pending Voice Message.
- [x] After a successful transcription, the pending Transcript stays in the State Store, so a retry does not transcribe again.
- [x] When the tool creates any Message Note, it erases the stored Transcript.
- [x] A missing audio file counts as a failed step.
- [x] If a step still fails 12 hours after the first-seen time, the tool creates the fallback Message Note.
- [x] The tool then marks the Voice Message as fallback.
- [x] The fallback for a failed Summary holds "Shrnutí se nepodařilo vytvořit" and the Transcript.
- [x] The fallback for a failed transcription or a missing audio file holds an error notice and no Transcript.
- [x] Each fallback Message Note produces one notification. A retry produces no notification.
- [x] The log records each failed attempt and the fallback, with no Transcript or Summary text.
- [x] "Run once" tests with a fake clock cover a retry that succeeds and both fallback bodies.
- [x] Tests also cover the missing audio file and the single fallback notification.

## Comments

A failed step no longer stops the run. `runOnce` logs the failed step, records the failure in the State Store and goes on to the next Voice Message. The State Store has the statuses `pending`, `done` and `fallback`. For each Voice Message, it records the first-seen time, the number of failed attempts and the last error. A pending Voice Message also keeps its Transcript and the audio duration, so a retry does not transcribe again and the log still shows the duration. `markDone` and `markFallback` erase the Transcript. An old `state.sqlite` gets the new columns when the State Store opens it.

The retry window is the configuration value `retryHours`, which is 12 if left out. If a step still fails after that window, the run creates the fallback Message Note. If the Summary failed, it holds "Shrnutí se nepodařilo vytvořit" and the Transcript. If transcription failed or the audio file is missing, it holds a Czech notice that names the failed step. The Transcriber throws `MissingAudioFile` for a missing audio file, and the core tells the two transcription cases apart by that error. Each fallback Message Note sends one notification that names the Tracked Contact and the failed step. The log has a `status=fallback` entry, and `run finished` now also counts the pending Voice Messages.

A failed Message Note creation has no fallback, because a fallback Message Note fails the same way. That Voice Message stays pending, and every run tries again with no end. Only the log shows this, so the user gets no notification. Ticket 07 covers the most likely cause, a missing Notes Folder. If the fallback Message Note itself fails, the Voice Message stays pending, and the State Store records the Notes error as the last error.

No automated test covers the real `WhisperKitTranscriber`, as the spec allows. A manual run with a missing audio file can make sure that the real adapter throws `MissingAudioFile`.
