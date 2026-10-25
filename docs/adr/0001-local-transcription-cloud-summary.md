# Local transcription, cloud summary

Voice Messages are private messages from another person. The audio never leaves the Mac. Whisper large-v3 transcribes it locally, and only the Transcript text goes to the Claude API to produce the Summary and Action Items. Local Whisper handles Czech well on Apple Silicon, so a cloud speech service adds no quality. But local language models write noticeably weaker Czech summaries than Claude, so the summary step stays in the cloud.

## Considered Options

- Fully local, with Whisper and a local language model. Nothing leaves the Mac, but the Czech Summaries are weaker. We rejected it for summary quality.
- Fully cloud, with audio sent to a cloud speech service. We rejected it because it sends the audio off the Mac and gives no accuracy gain over local Whisper.

## Consequences

The automation needs an Anthropic API key and network access. If the Claude API is unavailable for 12 hours, the Message Note falls back to the Transcript with no Summary.
