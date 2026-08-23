# Product notes

## Version 1.2 promise

Diary Transcription is Mac-first and vault-first. The user chooses an existing Obsidian vault, retains ownership of plain Markdown, and can append to a private daily file, a Quartz-ready blog draft, a study note, or any deliberately selected Markdown file in the vault. Voice is transcribed locally with an installable INT8 model and never sent to a transcription service.

The destination studio has four stable workspaces:

- **Diary** — today’s timestamped log under `Diary/`.
- **Blog** — new private drafts under `Writing/Blogs/`, including nested folders.
- **Notes** — plain Markdown under `Notes/` for study and working material.
- **Any file** — a new or existing Markdown file anywhere inside the vault.

Blog, Notes, and Any file offer new file, new folder + file, and continue-existing actions. Recent destinations are remembered locally and the selected file survives relaunch. Every continuation is append-only and begins at the end of the existing file.

The utility communicates the capture lifecycle directly:

- **Ready** — the vault is connected and the microphone action is available.
- **Checking microphone** — macOS permission is being resolved.
- **Listening** — local recording and real input metering are active.
- **Transcribing / Saving** — local inference and the coordinated Markdown append remain distinct.
- **Recording held locally** — a failed or interrupted entry is durable and recoverable.
- **Permission off / Error** — recovery actions are presented in place.
- **Saved** — a complete typed or transcribed entry was appended to the named destination and can be opened directly in Obsidian.

No daily file is created merely by launching, selecting a vault, or opening Settings. It appears only after the first valid entry is successfully persisted. Default folders may be prepared when the vault is connected. A blog draft is created only after the user chooses its location and starts private (`visibility: private`, `draft: true`).

## Transcription contract

Capture and transcription return final plain text to the existing writer boundary. They do not write vault files themselves. This keeps concurrency, local date naming, Markdown structure, and error handling centralized.

Microphone permission, AAC capture, metering, a 10-minute recording safety limit, 30-second inference chunking, queued pending-file recovery, destination-pinned retries, and Cohere Transcribe 2B INT8 inference through native Swift/MLX are implemented. Once installed, the normal capture path loads the pinned local snapshot without network fallback. V1 intentionally has no cloud transcription service and no cleanup LLM.

The compact Stats mode records only local aggregates: saved entry count, captured word count, spoken duration, streak, and a fourteen-day word ledger. Its ordered-pixel chart supports pointer scrubbing but never stores entry text.
