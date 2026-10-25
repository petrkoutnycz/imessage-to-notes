# iMessage to Notes

Status: ready-for-agent

## Problem Statement

One person regularly sends me Voice Messages in Czech over iMessage. To know what a Voice Message says, I must stop and listen to it. I cannot search, skim or keep its content in written form. I want the content of each Voice Message in writing, as a short summary in the Notes app, without any manual step.

## Solution

A background tool on my Mac runs every 5 minutes. It finds new Voice Messages that a Tracked Contact sends me in a Direct Chat. It transcribes each one locally and sends only the Transcript text to Claude to get a Czech Summary and any Action Items. It then creates one Message Note in my Notes Folder in iCloud, so the Message Note also appears on my iPhone. On the first run, it also processes Voice Messages from the last 7 days. If a step fails, it retries for 12 hours and then creates a fallback Message Note, so no Voice Message disappears silently. I get a macOS notification for each Message Note and for each problem. A log file records every run.

## User Stories

1. As the user, I want a Message Note for each Voice Message from a Tracked Contact, so that I can read it and not listen.
2. As the user, I want the Summary written in Czech, so that it matches the language of the Voice Message.
3. As the user, I want the Message Note to list the Action Items, so that I do not miss tasks, dates or requests.
4. As the user, I want no Action Items section in a Message Note that has no Action Items, so that the Message Note stays short.
5. As the user, I want the Message Note to contain no Transcript in the normal case, so that the Message Note stays short.
6. As the user, I want the contact name and the date and time in the title, so that I can find it in a list.
7. As the user, I want all Message Notes in one Notes Folder that I choose, so that they do not mix with my other notes.
8. As the user, I want the Notes Folder to be in my iCloud account, so that Message Notes sync to my iPhone.
9. As the user, I want a clear error for a missing Notes Folder, so that the tool never creates a folder.
10. As the user, I want a Tracked Contact to include all of their Handles, so that both their phone and email messages count.
11. As the user, I want to keep Tracked Contacts in a configuration file, so that I can add a person later with no code change.
12. As the user, I want Voice Messages from other people ignored, so that only Tracked Contacts are processed.
13. As the user, I want the tool to ignore group chats, so that only Direct Chats are processed.
14. As the user, I want the tool to ignore text messages, videos and attached audio files, so that only Voice Messages are processed.
15. As the user, I want the tool to ignore Voice Messages that I send, so that only incoming Voice Messages are processed.
16. As the user, I want a Message Note within about 5 minutes of a Voice Message arriving, so that the written content is available soon.
17. As the user, I want the tool to catch up after sleep or restart, so that no Voice Message is missed.
18. As the user, I want the first run to process the last 7 days, so that recent Voice Messages are not lost.
19. As the user, I want no Voice Messages older than that 7-day window processed, so that old history does not flood my Notes Folder.
20. As the user, I want at most one Message Note for each Voice Message, ever, so that I never get duplicates.
21. As the user, I want my edits and deletions of Message Notes to stay, so that the tool never overwrites them.
22. As the user, I want the audio to stay on my Mac, so that private recordings never go to a cloud service.
23. As the user, I want only the Transcript text to go to the Claude API, so that the minimum private data leaves my Mac.
24. As the user, I want my Anthropic API key read from the macOS Keychain, so that the key is not in a plain file.
25. As the user, I want failed steps retried for 12 hours, so that a short outage does not lose a Voice Message.
26. As the user, I want a fallback Message Note with the Transcript after 12 hours of failed Summaries, so that I keep the content.
27. As the user, I want a fallback Message Note with an error notice after 12 hours of failed transcription, so that no loss is silent.
28. As the user, I want a missing audio file treated as a failed step, so that a slow download gets more chances.
29. As the user, I want a macOS notification for each new Message Note, so that I know a Voice Message was processed.
30. As the user, I want notifications to show only the name and time, so that no Summary appears on my lock screen.
31. As the user, I want a click on the notification to open the Message Note in Notes, so that I can read it at once.
32. As the user, I want a macOS notification for each fallback Message Note, so that I know a step failed.
33. As the user, I want a notification for a missing Notes Folder, so that I can fix the configuration.
34. As the user, I want not to get the same problem notification every 5 minutes, so that one problem does not flood my screen.
35. As the user, I want a log file of every run, so that I can find out what happened to a Voice Message.
36. As the user, I want the log never to contain Transcript or Summary text, so that private content does not stay in a plain file.
37. As the user, I want log files older than 30 days deleted automatically, so that the log does not grow without limit.
38. As the user, I want Transcripts deleted from my Mac after the Message Note exists, so that less private text stays on disk.
39. As the user, I want the tool to keep Full Disk Access after I rebuild it, so that it does not silently stop reading Messages.
40. As the user, I want Full Disk Access only for this tool, so that other programs cannot read my messages.
41. As the user, I want the tool to start automatically at login, so that I do not have to remember to start it.
42. As the user, I want only one run at a time, so that overlapping runs do not create duplicates.
43. As the user, I want a setting to include the Transcript in the Message Note, so that I can read the full text when I want it.

## Implementation Decisions

- The tool is one native Swift binary inside a small app bundle, signed with an Apple Development certificate. See ADR 0002. The app bundle is necessary for notifications and for stable macOS privacy permissions.
- A per-user launchd agent starts the binary every 5 minutes and at login. Each start does one run and exits. The agent runs in the user session, which Notes and notifications need.
- The core is one "run once" operation. It takes the current time, the configuration and a set of adapters. It does all the work of one run. Everything outside the program goes through an adapter: Messages Reader, Transcriber, Summarizer, Notes Writer, Notifier, State Store, Log and Clock.
- The run once operation takes a file lock first. If another run holds the lock, the new run exits at once.
- Run order: load the configuration, make sure that the Notes Folder exists, and read candidate Voice Messages. Then skip the ones that are done, and process the rest in order of arrival.
- If the Notes Folder does not exist, the run stops before it processes any Voice Message. It logs the error and sends a notification at most once every 24 hours.
- The configuration is a JSON file in the tool's Application Support folder. It holds the Tracked Contacts (name plus Handles) and the Notes Folder name. It also holds the backfill window in days (`backfillDays`, 7 if left out), the retry window (12 hours) and the Claude model ID. It also holds `includeTranscript`, which is false if left out. This setting decides if the normal Message Note holds the Transcript. The backfill start does not move from run to run. Only an edit of `backfillDays` moves it.
- Handle matching: the code compares phone numbers after it removes spaces and punctuation, in international format with the country code. It compares email addresses without regard to letter case. A Handle with `@` is an email address. For any other Handle, only the digits count.
- Messages Reader: it opens the Messages database read-only and returns candidate Voice Messages. A candidate is an audio message from a Handle of a Tracked Contact, in a one-to-one chat or with no chat link. It is not from me, and its date is on or after the backfill start. The reader returns candidates in order of arrival. It returns the message GUID, the Handle, the sent date and the path of the audio file.
- The expected database markers are a flag for audio messages and a flag for messages from me. A chat style separates one-to-one chats from group chats, and a join table links attachments. Dates use Apple's epoch (2001-01-01) in nanoseconds. The first ticket must make sure that these markers match the real database on this Mac.
- Database markers on this Mac (verified 2026-10-25 by the probe in ticket 01): `message.is_audio_message` = 1 marks a Voice Message, and `message.is_from_me` = 0 marks an incoming message. `chat.style` is 45 for a one-to-one chat and 43 for a group chat. `message_attachment_join` links the attachment. `message.date` is in nanoseconds since 2001-01-01. A Voice Message attachment has the UTI `com.apple.coreaudio-format`, no MIME type and the file name `Audio Message.caf`. It holds Opus audio, 1 channel, 24 kHz, which decodes on this Mac. The Notes account name is `iCloud`.
- Difference from the expected markers: many messages have no row in `chat_message_join`, so they have no chat and no chat style. On this Mac, about 3,500 messages have no chat link, and 3 of the 5 newest Voice Messages from the Tracked Contact have none. A Messages Reader that requires chat style 45 misses these Voice Messages. `message.cache_roomnames` is empty for every message, so it cannot mark group messages. Decision in ticket 02, accepted by the user: a Voice Message with no chat link counts as a Direct Chat message when its Handle belongs to a Tracked Contact. Only a link to a chat with a style other than 45 excludes a Voice Message. The risk is that a group chat Voice Message with no chat link produces a Message Note.
- Backfill start: the State Store records the time of the first run. The backfill start is that time minus the backfill window, and it does not move from run to run. Every run considers all Voice Messages after the backfill start that are not done.
- Transcriber: WhisperKit with the Whisper large-v3 model, language fixed to Czech with no auto-detection. Input is the audio file path. Output is the Transcript text. The first ticket must make sure that the Voice Message audio format decodes on this Mac.
- Summarizer: the Claude Messages API with model `claude-sonnet-5-5` (see ADR 0001). The API key comes from the macOS Keychain. Input is the Transcript. Output is a Summary of 2 to 4 sentences of Czech prose plus a list of Action Items, which can be empty. The request asks for a structured response, so the code never parses free text.
- Notes Writer: it creates a note through AppleScript in the Notes Folder of the iCloud account, with an HTML body, and returns the note ID. It also opens a note by ID, for the notification click. It needs the macOS Automation permission for Notes.
- Message Note title: `<Tracked Contact name> – <YYYY-MM-DD HH:MM>`, in local time, from the sent date of the Voice Message.
- Message Note body in the normal case: the Summary. If Action Items exist, an "Úkoly" (Action Items) list follows. If `includeTranscript` is true, a bold "Přepis" (Transcript) heading and the Transcript come last, as one paragraph. If it is false, there is no Transcript.
- At the creation of each Message Note, the tool reads the current `includeTranscript` value. It never changes an existing Message Note after a change of the setting. The setting does not change the fallback bodies.
- Fallback body after a failed Summary: the line "Shrnutí se nepodařilo vytvořit", then the Transcript.
- Fallback body after failed transcription or a missing audio file: a Czech error notice that names the failed step. There is no Transcript.
- State Store: a small SQLite database in the tool's Application Support folder. For each Voice Message, it records the GUID, the first-seen time and the status (pending, done or fallback). It also records the attempt count, the last error and the Message Note ID. It also records the first-run time.
- A pending Voice Message keeps its Transcript in the State Store, so a retry does not transcribe again. When the code creates the Message Note, it erases the Transcript. This follows the rule that no Transcript stays after the Message Note exists.
- Retry rule: a failed step leaves the Voice Message pending. Each run retries it. If the step still fails 12 hours after the first-seen time, the run creates the fallback Message Note. It then marks the Voice Message as fallback.
- Notifier: macOS user notifications. On success, the text is "Nová hlasová zpráva od <name> zpracována" plus the time. Fallback notifications name the contact and the failed step. A notification carries the Message Note ID, and a click starts the app, which opens that Message Note.
- A problem notification for a fallback comes once, at the creation of the fallback Message Note, and not on every retry.
- Log: daily text files in the tool's folder under the user Logs folder. Each entry holds the Voice Message GUID, timestamps, audio duration, the Tracked Contact name, the step status and error details. It never holds Transcript or Summary text. Each run deletes log files older than 30 days.

## Testing Decisions

- A good test drives the tool from the outside and asserts on what the user sees: which Message Notes exist, with what title and body, what the State Store records, what the log says and which notifications fire. It never asserts on internal calls or private types.
- Main seam: the run once operation, called with fake adapters and a fake clock. These tests cover Tracked Contacts only, Direct Chats only, the backfill window and at most one Message Note per Voice Message. They also cover the 12-hour retry, both fallback bodies, the missing audio file and the missing Notes Folder. They also cover the normal body with `includeTranscript` off and on. Last, they cover the notification limits, the run lock and the rule that the log holds no Transcript or Summary text.
- Second seam: the Messages Reader, tested against small SQLite fixture files that copy the parts of the Messages database schema that the reader uses. These tests cover audio versus other messages, from-me messages, one-to-one versus group chats, Handle matching across phone numbers and emails, and Apple epoch date filtering.
- The real WhisperKit, Claude API, Notes, notification and Keychain adapters get no automated tests. A manual smoke run on the Mac, with one real Voice Message, makes sure that they work.
- The repo has no prior art. Tests use the Swift testing framework that comes with Xcode.

## Out of Scope

- Group chats, text messages, videos and attached audio files.
- Voice Messages that I send.
- Languages other than Czech.
- Voice Messages older than the 7-day backfill window, and any later backfill command.
- Long-term Transcript storage outside the Message Note.
- Recreating or updating a Message Note after creation.
- A user interface beyond notifications.
- iPhone or iPad. The tool runs on this one Mac only.
- More than one Mac running the tool. Two Macs create duplicate Message Notes.
- Notes accounts other than iCloud.

## Further Notes

- Several setup steps need a human, and a `/wizard` script fits them:
  - Install full Xcode.
  - Create the Apple Development certificate.
  - Grant Full Disk Access and the Notes Automation permission.
  - Put the API key into the Keychain.
  - Create the Notes Folder.
- iPhone audio message expiry stays at its current setting, because I never play these Voice Messages myself. If I play one, the audio can expire before the tool reads it. In that case the missing audio file rule applies.
- Messages in iCloud must be on for this Mac, and the Mac must be on and logged in for runs to happen.
- The first ticket is a thin end-to-end path, from one real Voice Message to one Message Note. It must make sure that the database markers, the audio decoding and the Notes iCloud account name match what this spec expects.
- Vocabulary follows `GLOSSARY.md`. Decisions follow ADR 0001 and ADR 0002.
