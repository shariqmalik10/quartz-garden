# Diary Transcription for macOS

A native macOS 14+ menu-bar utility that writes ordinary Markdown diary entries into an existing Obsidian vault.

## Phase 2 capture milestone

This package now includes the filesystem foundation and a native microphone-capture surface:

- choose an existing Obsidian vault with `NSOpenPanel`;
- persist access using a macOS security-scoped bookmark;
- ensure `<Vault>/Diary/` exists without creating a daily note prematurely;
- append to `diary-log_YYYY-MM-DD.md` using the Mac's local calendar;
- create the first note as `# Diary Log — YYYY-MM-DD` followed by `## HH:mm` and entry text;
- preserve all earlier content and serialize near-simultaneous appends;
- coordinate file mutations with `NSFileCoordinator` and atomically publish the first note;
- request microphone access only when capture begins;
- record local mono AAC audio and meter the real input level;
- display a responsive 31-bar waveform with a Reduced Motion mode;
- retain pending audio under Application Support across launches until explicit discard;
- show explicit permission, listening, captured, saved, and error states.

The captured audio is intentionally labelled as pending. Local Cohere/MLX transcription is the next milestone; this version does not fabricate a transcript or send the recording to a cloud service. The manual entry field remains available behind **Write instead** and exercises the same durable Markdown writer.

## Run locally

Build the app bundle before testing microphone capture. The bundle supplies the macOS privacy description and audio-input entitlement:

```sh
./scripts/build-app.sh
open .build/DiaryTranscription.app
```

The app appears in the menu bar. Choose an existing vault, press the microphone button or `⌘⇧R`, grant microphone access if macOS asks, and speak. Stop the recording to retain it locally. Use **Show file** to inspect it or **Discard** to remove it.

`swift run DiaryTranscription` is still useful for layout work, but the raw executable has no application bundle metadata and should not be used to test the microphone permission flow.

Run the test suite with:

```sh
swift test
```

## Privacy and storage

Entries are normal `.md` files. There is no database and no proprietary index. This milestone performs no networking. The app stores the vault bookmark in `UserDefaults`; the selected vault remains the source of truth.

Pending recordings live at:

```text
~/Library/Application Support/DiaryTranscription/Pending Audio/
```

A recording is not deleted merely because the menu-bar window closes or the app restarts. The newest pending recording is recovered on launch. Deletion is explicit until the later pipeline can prove both transcription and Markdown append succeeded.

## Later phases

The next milestone adds local Cohere Transcribe 2B inference through native Swift/MLX with INT8 weights. Its final plain text will pass to `DiaryWriter.append(_:at:)`; filesystem behavior should not need to change. After the model is installed, transcription remains offline. V1 has no cloud transcription path, no cleanup LLM, and no network dependency during capture or transcription.
