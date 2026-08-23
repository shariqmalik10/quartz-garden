# Product notes

## Version 1.0 promise

Diary Transcription is Mac-first and vault-first. The user chooses an existing Obsidian vault, retains ownership of plain Markdown, and gets one append-only daily file under `Diary/`. Voice is transcribed locally with an installable INT8 model and never sent to a transcription service.

The utility communicates the capture lifecycle directly:

- **Ready** — the vault is connected and the microphone action is available.
- **Checking microphone** — macOS permission is being resolved.
- **Listening** — local recording and real input metering are active.
- **Transcribing / Saving** — local inference and the coordinated Markdown append remain distinct.
- **Recording held locally** — a failed or interrupted entry is durable and recoverable.
- **Permission off / Error** — recovery actions are presented in place.
- **Saved** — a complete manual or future transcribed entry was appended to the named daily file.

No daily file is created merely by launching, selecting a vault, or opening Settings. It appears only after the first valid entry is successfully persisted.

## Transcription contract

Capture and transcription return final plain text to the existing writer boundary. They do not write vault files themselves. This keeps concurrency, local date naming, Markdown structure, and error handling centralized.

Microphone permission, AAC capture, metering, a 10-minute recording safety limit, 30-second inference chunking, queued pending-file recovery, and Cohere Transcribe 2B INT8 inference through native Swift/MLX are implemented. Once installed, the normal capture path loads the pinned local snapshot without network fallback. V1 intentionally has no cloud transcription service and no cleanup LLM.
