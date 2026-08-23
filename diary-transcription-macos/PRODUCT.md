# Product notes

## Current promise

Diary Transcription is Mac-first and vault-first. The user chooses an existing Obsidian vault, retains ownership of plain Markdown, and gets one append-only daily file under `Diary/`. Phase 2 adds honest local microphone capture without weakening the safe writer boundary.

The utility communicates the capture lifecycle directly:

- **Ready** — the vault is connected and the microphone action is available.
- **Checking microphone** — macOS permission is being resolved.
- **Listening** — local recording and real input metering are active.
- **Recording held locally** — audio is durable and pending local transcription.
- **Permission off / Error** — recovery actions are presented in place.
- **Saved** — a complete manual or future transcribed entry was appended to the named daily file.

No daily file is created merely by launching, selecting a vault, or opening Settings. It appears only after the first valid entry is successfully persisted.

## Follow-on transcription contract

Future capture and transcription components should return final plain text to the existing writer boundary. They must not write vault files themselves. This keeps concurrency, local date naming, Markdown structure, and error handling centralized.

Microphone permission, local AAC capture, input metering, pending-file recovery, and the live waveform are now implemented. Follow-on work is resilient audio chunking and local Cohere Transcribe 2B inference through native Swift/MLX using INT8 weights. Once the model is installed, v1 capture and transcription must operate without a network connection. V1 intentionally has no cloud transcription service and no cleanup LLM; the local transcript flows directly into the existing writer boundary.
