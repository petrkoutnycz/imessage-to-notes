# iMessage to Notes

Turns Czech voice messages that a known person sends over iMessage into written summaries in the Apple Notes app.

## Language

### Input

**Voice Message**:
An audio recording that a Tracked Contact makes with the microphone button in Messages and sends to you in a Direct Chat. Always spoken in Czech.
_Avoid_: Audio message, iMessage, attachment, audio file

**Tracked Contact**:
A person whose Voice Messages the automation processes, identified by a name and all of their Handles.
_Avoid_: Sender, user, contact

**Handle**:
One address that a person uses in Messages: a phone number or an iCloud email address.
_Avoid_: ID, account

**Direct Chat**:
A one-to-one Messages conversation between you and one other person. Group chats are not Direct Chats.
_Avoid_: DM, conversation, thread

### Output

**Transcript**:
The full Czech text of what the speaker says in one Voice Message.
_Avoid_: Transcription (as a noun for the text)

**Summary**:
A short Czech restatement of the content of one Transcript.
_Avoid_: Abstract, digest

**Action Item**:
A task, date or request that the speaker mentions in a Voice Message.
_Avoid_: To-do, task, follow-up

**Message Note**:
The one note in the Notes Folder for one Voice Message. It holds the Summary and any Action Items. If you choose, it also holds the Transcript. A Fallback Message Note is the exception.
_Avoid_: Note (alone), transcript note, entry

**Fallback Message Note**:
The Message Note for a Voice Message that the automation cannot process within the Retry Window. If only the Summary failed, it holds the Transcript. If no Transcript exists, it holds a notice of the failure.
_Avoid_: Error note, placeholder

**Notes Folder**:
The one folder in your iCloud Notes account that you choose to hold all Message Notes.
_Avoid_: Target folder, destination

### Processing

**Run**:
One pass of the automation that turns every Voice Message that is not Done into a Message Note. A Run starts every 5 minutes and at login.
_Avoid_: Job, sync, poll

**Backfill Window**:
The number of days before the first Run from which the automation also processes Voice Messages.
_Avoid_: History, lookback

**Backfill Start**:
The time of the first Run minus the Backfill Window. The automation never processes a Voice Message sent before it.
_Avoid_: Cutoff, since date

**Retry Window**:
The number of hours that the automation keeps trying a Pending Voice Message, counted from the first Run that finds it. After that, the Voice Message gets a Fallback Message Note.
_Avoid_: Timeout, grace period

**Pending**:
The state of a Voice Message whose processing failed and that the next Run tries again.
_Avoid_: Queued, failed, in progress

**Done**:
The state of a Voice Message that has its Message Note, normal or fallback. No Run processes it again.
_Avoid_: Processed, handled, complete
