# Product notes

## Current promise

Diary Transcription is Mac-first and vault-first. The user chooses an existing Obsidian vault, retains ownership of plain Markdown, and gets one append-only daily file under `Diary/`. Phase 1 proves durable access and safe writes before audio or model complexity is introduced.

The utility communicates three states:

- **Ready** — bookmark access resolved and the vault's `Diary/` directory is available.
- **Saved** — a complete entry was appended to the named daily file.
- **Error** — the vault is unavailable, configuration is missing, the entry is empty, or a coordinated write failed.

No daily file is created merely by launching, selecting a vault, or opening Settings. It appears only after the first valid entry is successfully persisted.

## Follow-on transcription contract

Future capture and transcription components should return final plain text to the existing writer boundary. They must not write vault files themselves. This keeps concurrency, local date naming, Markdown structure, and error handling centralized.

Planned follow-on work includes microphone permissions and recording controls, resilient audio chunking, and local Cohere Transcribe 2B inference through native Swift/MLX using INT8 weights. Once the model is installed, v1 capture and transcription must operate without a network connection. V1 intentionally has no cloud transcription service and no cleanup LLM; the local transcript flows directly into the existing writer boundary.
