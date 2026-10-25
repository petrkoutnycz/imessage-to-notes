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
