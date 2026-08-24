<p align="center">
  <img src="Resources/Yap-AppIcon-1024.png" width="112" alt="Yap app icon">
</p>

# Yap

Speak a thought and keep it as plain Markdown. Yap is a native macOS menu-bar app that transcribes locally with Apple MLX and appends directly to an Obsidian vault.

## Requirements

- Apple-silicon Mac running macOS 15 or newer
- An existing Obsidian vault
- Xcode 16+ and the Metal Toolchain for local builds
- About 2.42 GB for the optional Cohere Transcribe INT8 model

## Build and open

```sh
xcodebuild -downloadComponent MetalToolchain
swift test
./scripts/build-app.sh
open .build/Yap.app
```

Create the installable disk image with:

```sh
./scripts/build-dmg.sh
open dist/Yap-1.2.0.dmg
```

## First run

1. Open Yap from the menu bar and choose the folder containing your Obsidian vault.
2. Open Settings and install the local transcription model. The first download needs internet; transcription is offline afterward.
3. Choose **Resume / switch**, then select Diary, Blog, Notes, or any Markdown file.
4. Press the microphone, speak, and press Stop. Yap appends the transcript and can open the exact file in Obsidian.

No global shortcut is assigned by default. You can record one in Settings.

## Destinations

| Mode     | Default location                         |
| -------- | ---------------------------------------- |
| Diary    | `Diary/diary-log_YYYY-MM-DD.md`          |
| Blog     | `Writing/Blogs/<title>.md`               |
| Notes    | `Notes/<title>.md`                       |
| Any file | Any `.md` file inside the selected vault |

Existing content is never replaced. Blog drafts begin with `visibility: private` and `draft: true`; change both when they are ready for Quartz.

Pending audio and the downloaded model remain in `~/Library/Application Support/DiaryTranscription/` so upgrading from the previous Diary Transcription build does not discard data or trigger another model download.

## Privacy and recovery

Audio and transcription stay on the Mac. Audio is removed only after the Markdown append succeeds. Interrupted recordings are recovered on the next launch with Retry, Show Audio, and Discard controls.

Local builds are ad-hoc signed. Public distribution still requires Developer ID signing and Apple notarization.
