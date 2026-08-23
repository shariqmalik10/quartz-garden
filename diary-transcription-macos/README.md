# Diary Transcription for macOS

A native Apple-silicon macOS 15+ menu-bar app that records a thought, transcribes it locally with Cohere Transcribe 2B INT8 through Apple MLX, and appends plain Markdown to an existing Obsidian vault.

## What version 1.0 does

- remembers an existing Obsidian vault using a security-scoped bookmark;
- creates `<Vault>/Diary/` and appends to `diary-log_YYYY-MM-DD.md`;
- records mono AAC locally and displays a live 31-bar microphone waveform;
- installs a pinned 2.42 GB INT8 model once, then loads and transcribes strictly from local files;
- warms the model while recording and keeps it resident between entries;
- chunks longer audio into safe 30-second inference windows;
- stores pending audio and a transcript sidecar until the Markdown append succeeds;
- recovers unfinished work after relaunch and offers Retry, Show audio, or Discard;
- enforces a 10-minute capture limit so accidental long recordings cannot exhaust memory;
- serializes appends and uses `NSFileCoordinator` so existing notes are preserved;
- supports 14 transcription languages;
- offers an optional user-recorded global shortcut, disabled by default;
- keeps a manual writing fallback and a quick action to open today's diary.

There is no cloud transcription, cleanup LLM, database, or proprietary note format.

## Build and run

Xcode's downloadable Metal Toolchain must be installed once because MLX compiles a Metal shader library:

```sh
xcodebuild -downloadComponent MetalToolchain
./scripts/build-app.sh
open .build/DiaryTranscription.app
```

To create the drag-to-Applications disk image:

```sh
./scripts/build-dmg.sh
```

The result is `dist/DiaryTranscription-1.0.0.dmg`.

The package script builds an ad-hoc-signed local app and copies SwiftPM resource bundles, including `default.metallib`, into the application. Test with:

```sh
swift test
```

## First-use setup

1. Open the menu-bar app and choose the folder that contains your Obsidian vault.
2. Choose **Install** for the 2.42 GB Cohere INT8 model. The first installation needs internet access.
3. Optionally open Settings to select a language or record a global shortcut. No shortcut is assigned by default; safe shortcuts require at least two modifiers, and Delete clears one.
4. Press the microphone, speak, and press Stop. The app transcribes locally and appends the result.

## Where everything goes

| Content                            | Location                                                          |
| ---------------------------------- | ----------------------------------------------------------------- |
| Final diary notes                  | `<Your Vault>/Diary/diary-log_YYYY-MM-DD.md`                      |
| Pending recordings                 | `~/Library/Application Support/DiaryTranscription/Pending Audio/` |
| Downloaded model                   | `~/Library/Application Support/DiaryTranscription/Models/`        |
| Vault bookmark, language, shortcut | macOS `UserDefaults` for `com.shariq.DiaryTranscription`          |

The daily Markdown format is:

```md
# Diary Log — 2026-08-23

## 23:54

The transcribed or manually written entry.
```

Audio is deleted only after its transcript has been successfully appended. If transcription or writing fails, the recording remains recoverable. Model removal is available in Settings and never touches diary files.

The app stops a recording at 10 minutes and keeps it for explicit transcription or discard. If more than one interrupted recording exists, it surfaces them oldest-first rather than abandoning older audio.

## Distribution note

The local build is ad-hoc signed. A public release should additionally use a Developer ID certificate, notarization, hardened runtime, and a signed update channel.
