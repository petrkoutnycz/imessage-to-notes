# Manual smoke run

This procedure makes sure that the real adapters work on this Mac with one real Voice Message. The adapters are the Messages Reader, the Transcriber, the Summarizer and the Notes Writer. Ticket 08 replaces these steps with a setup wizard.

Always start the app with `open`. If you start the binary directly from a terminal, macOS checks the permissions of the terminal and not the permissions of the app.

## Build

1. Run `scripts/build-app.sh` in the repository folder.
2. Make sure that the script prints `Built build/ImessageToNotes.app`.

## Set up

1. Create the Notes Folder in the iCloud account of the Notes app.
2. Copy `App/config.example.json` to `~/Library/Application Support/imessage-to-notes/config.json`.
3. In `config.json`, write the name of the Tracked Contact, all of their Handles and the Notes Folder name. Write phone numbers in international format with no spaces, for example `+420777123456`.
4. Put the API key into the login keychain. The command asks for the key:

   ```
   security add-generic-password -s imessage-to-notes -a anthropic-api-key -w
   ```

5. In System Settings, open Privacy & Security, then Full Disk Access. Add `build/ImessageToNotes.app` and turn it on.

## Probe

The probe prints how the real Messages database, the audio file and the Notes accounts match the spec. It prints metadata only, never message text.

1. Run this command:

   ```
   open -W --stdout "$(tty)" --stderr "$(tty)" build/ImessageToNotes.app --args probe
   ```

2. If macOS asks if the app can control Notes, click Allow.
3. Compare the output with the database markers in `.scratch/imessage-to-notes/spec.md`. Write each difference into the spec.

The tool compares Handles without regard to the format of phone numbers or the letter case of email addresses. The "newest audio messages" lines of the probe use exact Handles only. If an "audio sender" line says "normalized match", a run finds the Voice Messages of that sender.

## Sample file

You can test the Transcriber and the Summarizer on one audio file, for example a Voice Message that you saved from Messages. This step needs no Full Disk Access.

1. Run this command, with the path of the audio file:

   ```
   open -W --stdout "$(tty)" --stderr "$(tty)" build/ImessageToNotes.app --args sample "$HOME/Downloads/Audio Message.caf"
   ```

2. Make sure that the Transcript is in Czech and that the Summary has 2 to 4 Czech sentences.

The command shows the Transcript in the terminal only. It writes no Transcript to disk.

## Run

1. Run the same `open` command with `--args run` in place of `--args probe`. On the first run, WhisperKit downloads the Whisper large-v3 model, which takes several minutes.
2. If macOS asks if the app can use the keychain item, click Always Allow.
3. Make sure that the Message Note appears in the Notes Folder on the Mac and on the iPhone.
4. Run the command again. Make sure that the output says that the Voice Message is already done, and that no second Message Note appears.

## Rebuild

1. Run `scripts/build-app.sh` again.
2. Run the probe again. Make sure that it reads the Messages database with no new Full Disk Access grant.

## Background runs

A per-user launchd agent starts the app at login and every 5 minutes. Each start does one run and exits. The agent runs in the user session, so the app can use Notes and notifications. Each run takes the lock file `~/Library/Application Support/imessage-to-notes/run.lock` first. If another run holds the lock, the new run prints `Another run is active. This run does nothing.` and exits.

1. Run `scripts/build-app.sh` in the repository folder.
2. Run `scripts/load-agent.sh`. The script copies the app to `~/Applications/ImessageToNotes.app`. It writes the agent definition, a property list file, to `~/Library/LaunchAgents/cz.petrkoutny.imessage-to-notes.plist`, and loads the agent. The agent starts the first run at once.
3. If macOS asks if the app can control Notes or use the keychain item, click Allow or Always Allow. launchd starts the binary directly and not through `open`, so macOS can ask again.
4. Make sure that the log file of today in `~/Library/Logs/imessage-to-notes` shows the entries of the first run. See "Run log".
5. Ask the Tracked Contact to send a Voice Message. Make sure that the Message Note appears in the Notes Folder within about 5 minutes, with no manual start.

The app in `~/Applications` has the same signature as the app in `build/`, so it keeps Full Disk Access. If a new build is ready, run `scripts/load-agent.sh` again. To stop background runs, run `scripts/unload-agent.sh`. This script unloads the agent and removes its property list file. The app, the configuration and the State Store stay.

If you run `scripts/load-agent.sh` or `scripts/unload-agent.sh` during a run, launchd stops that run. A run that stops after the Notes Writer creates the Message Note, but before the State Store records it, causes a duplicate Message Note in the next run.

launchd starts no new run while a run is active. If a run waits for a permission dialog that nobody answers, no further runs occur. If the log shows no new `run started` entry for more than 5 minutes, look for an open dialog.

## Run log

Each run writes entries to a daily text file in `~/Library/Logs/imessage-to-notes`, for example `2026-10-25.log`. Each run that gets the lock deletes the log files that are older than 30 days. If the deletion fails, the log shows `log cleanup failed` and the run continues. If the tool cannot write the log, the run stops. The agent keeps no other output, so a background run prints nothing to a file.

An entry about a Voice Message holds its GUID, the time of the entry, the sent time and the Tracked Contact name (`tracked-contact`). It also holds the step status and the error details of a failed step. The entries after the transcription also hold the audio duration. An entry never holds Transcript or Summary text. If an error quotes 10 or more characters of a Transcript or a Summary, the log shows `[redacted]` in place of that text.

1. After a run, open the log file of today.
2. Make sure that the entries of the run start with `run started`.
3. Make sure that each new Voice Message has a `status=done` entry with the note ID.
4. Make sure that the file contains no Transcript or Summary text.

## Notifications

Each new Message Note produces one notification. The title is `Nová hlasová zpráva od <name> zpracována`, and the text is the sent time of the Voice Message. A notification never holds Summary or Transcript text. The first notification asks for the notification permission. If nobody answers within 60 seconds, that run sends no notifications, and the log shows `status=failed step=notify` for each new Message Note of the run. A failed notification does not stop the run.

1. Run `scripts/build-app.sh`, then run `scripts/load-agent.sh`.
2. Ask the Tracked Contact to send a Voice Message.
3. If macOS asks if iMessage to Notes can send notifications, allow it.
4. Make sure that the notification shows the Tracked Contact name and the time, and no Summary text.
5. Make sure that the log file of today has a `status=notified` entry with the note ID.
6. Click the notification. Make sure that Notes opens that Message Note.

If you click a notification after the run ends, macOS starts the app with no arguments. The app then waits up to 30 seconds for the click, opens the Message Note and quits. If Notes does not open the Message Note, look for a `message note open failed` entry in the log.

## Missing Notes Folder

If the Notes Folder is missing in the iCloud account, a run stops before it processes any Voice Message. It creates no folder. It sends a notification at most once every 24 hours.

1. Run `scripts/build-app.sh`.
2. In Notes, rename the Notes Folder, for example to `Hlasové zprávy (test)`.
3. Run `imessage-to-notes probe`. Make sure that it shows the Notes Folder as `MISSING`.
4. Run the app with the `run` command. Make sure that the log file of today has a `run stopped: notes folder missing` entry.
5. Make sure that a notification says `Složka pro hlasové zprávy chybí`. Click it. Make sure that the app quits and opens nothing.
6. Run the app with the `run` command again. Make sure that no second notification appears.
7. Make sure that Notes has no new folder.
8. Rename the folder back to the Notes Folder name. Run the app with the `run` command. Make sure that the run processes the waiting Voice Messages.

The State Store keeps the time of the last notification. After this test, the next notification about a missing folder can come only 24 hours after step 5.
