# 08: Install and setup wizard

**What to build:** I can set up the tool on my Mac by following one interactive script. It walks me through each step that only I can do, and it installs and starts the tool. A short README explains what the tool does and how to install, update and remove it.

This ticket uses the `/wizard` skill. See the spec at `.scratch/imessage-to-notes/spec.md` and ADR 0002.

**Blocked by:** 03 (Background runs).

**Status:** ready-for-agent

- [ ] The wizard walks the human through these steps:
  - Install full Xcode.
  - Create the Apple Development certificate.
  - Put the Anthropic API key into the Keychain.
  - Create the Notes Folder in the iCloud account.
  - Write the configuration with the Tracked Contact and the Notes Folder name.
  - Grant Full Disk Access and the Notes Automation permission to the app.
- [ ] The configuration that the wizard writes holds `"includeTranscript": false`, so I can see the setting and change it later.
- [ ] The wizard builds the signed app, installs it and loads the launchd agent.
- [ ] The wizard can run again safely, and it skips steps that are already done.
- [ ] The README explains install, update and removal, including how to unload the launchd agent.
- [ ] The README states that Messages in iCloud must be on and that the Mac must be on and logged in.
