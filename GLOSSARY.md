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
The one note in the Notes Folder for one Voice Message. It holds the Summary and any Action Items. If you choose, it also holds the Transcript. If no Summary exists, it holds the Transcript.
_Avoid_: Note (alone), transcript note, entry

**Notes Folder**:
The one folder in your iCloud Notes account that you choose to hold all Message Notes.
_Avoid_: Target folder, destination
