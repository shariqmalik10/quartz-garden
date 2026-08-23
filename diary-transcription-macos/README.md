# Diary Transcription for macOS

A native macOS 14+ menu-bar utility that writes ordinary Markdown diary entries into an existing Obsidian vault.

## Phase 1 milestone

This package implements the filesystem foundation and a safe manual-entry UI:

- choose an existing Obsidian vault with `NSOpenPanel`;
- persist access using a macOS security-scoped bookmark;
- ensure `<Vault>/Diary/` exists without creating a daily note prematurely;
- append to `diary-log_YYYY-MM-DD.md` using the Mac's local calendar;
- create the first note as `# Diary Log — YYYY-MM-DD` followed by `## HH:mm` and entry text;
- preserve all earlier content and serialize near-simultaneous appends;
- coordinate file mutations with `NSFileCoordinator` and atomically publish the first note;
- show explicit Ready, Saved, and Error states in a menu-bar window and Settings scene.

The test-entry field is intentionally the only capture input in Phase 1. It exercises the same writer that later transcription will use without requiring a microphone or sending data anywhere.

## Run locally

```sh
swift run DiaryTranscription
```

The app appears in the menu bar. Open it, choose an existing vault, enter test text, and append it to today's diary.

Run the test suite with:

```sh
swift test
```

## Privacy and storage

Entries are normal `.md` files. There is no database and no proprietary index. Phase 1 performs no networking. The app stores only the vault bookmark in `UserDefaults`; the selected vault remains the source of truth.

## Later phases

Microphone capture, audio chunking, and speech-to-text are deliberately out of scope for this milestone. The planned v1 transcription pipeline runs Cohere Transcribe 2B locally through native Swift/MLX with INT8 weights, then passes the transcript to `DiaryWriter.append(_:at:)`; filesystem behavior should not need to change. After the model is installed, transcription remains offline. V1 has no cloud transcription path, no cleanup LLM, and no network dependency during capture or transcription.
