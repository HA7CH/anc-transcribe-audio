# HA7CH Transcribe Audio

An open Codex Skill that turns a user-provided local audio file into a faithful transcript. It is published by HA7CH but has no dependency on ANC, a HA7CH vault, or a specific workspace layout.

Supported direct inputs include WAV, MP3, M4A/MP4 AAC, FLAC, Ogg Opus, and WebM Opus. Long recordings are split locally into ten-minute WAV chunks before transcription. WeChat SILK works when a compatible `rust-silk` decoder is installed.

## Install

Ask Codex:

> Install the Skill from https://github.com/HA7CH/transcribe-audio-skill

Then install its runtime dependency:

```bash
brew tap wangnov/tap
brew install codex-asr
```

`ffmpeg` is also required when a recording is longer than ten minutes:

```bash
brew install ffmpeg
```

After installation, ask Codex to use `$transcribe-audio` on a local audio file, for example:

> Use $transcribe-audio to produce the original Chinese transcript of this WAV file.

## What happens to the audio

The Skill invokes the open-source [`codex-asr`](https://github.com/Wangnov/codex-asr) CLI. That tool reads the ChatGPT login already stored by Codex Desktop and uploads the selected audio to ChatGPT's non-public `backend-api/transcribe` endpoint. The Skill does not scan directories, persist transcripts, or copy authentication data.

This is an unofficial local adapter, not the official OpenAI Audio API. The upstream endpoint has no public stability or service-level guarantee and may change without notice. Use it for personal local workflows, not as a shared production transcription service.

## Development

```bash
bash scripts/test-transcribe-audio.sh
python3 /path/to/skill-creator/scripts/quick_validate.py .
```

## License

MIT. The runtime dependency `codex-asr` is a separate MIT-licensed project by its own contributors.
