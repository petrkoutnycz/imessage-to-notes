# Single signed Swift binary with its own Full Disk Access

Reading the Messages database needs Full Disk Access, and macOS grants that permission per executable and ties it to the code signature. The automation is one native Swift binary. It uses WhisperKit for transcription, is signed with an Apple Development certificate, and holds Full Disk Access by itself. launchd runs it every 5 minutes.

## Considered Options

- Python with `mlx-whisper`, launched by Homebrew `python3`. We rejected it because, with that option, Full Disk Access applies to every Python script on the Mac.
- Python with a small launcher app that holds the permission. We rejected it because it adds a launcher layer and a Python environment to maintain, for no gain over a native binary.

## Consequences

An ad hoc signature changes on every rebuild, and macOS then silently removes Full Disk Access. A build must always use the same Apple Development certificate. This needs full Xcode, not only the Command Line Tools.
