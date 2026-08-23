# Diary Transcription for macOS

A native Apple-silicon macOS 15+ menu-bar app that records a thought, transcribes it locally with Cohere Transcribe 2B INT8 through Apple MLX, and appends plain Markdown to an existing Obsidian vault.

## What version 1.2 does

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
- keeps a manual writing fallback and a quick action to open today's diary;
- opens the exact saved file directly in Obsidian through `obsidian://`;
- switches between **Speak**, **Write**, and a local pixel-style **Stats** ledger at the top;
- can append future recordings or typed text to any existing Markdown file inside the vault;
- offers a destination studio for Diary, Blog, Notes, and Any Markdown;
- creates default `Diary/`, `Writing/Blogs/`, and `Notes/` workspaces;
- offers new file, new folder + file, recent-file resume, and existing-file selection flows;
- creates private Quartz-ready blog drafts under `Writing/Blogs/`;
- remembers the selected destination across launches and pins it into pending recovery metadata;
- offers eight themes, including Dither Signal, Cobalt, Solar Paper, and Rosewood;
- offers six input visualizations, including ribbon, radial, and ordered-dither signals;
- renders a scrub-responsive fourteen-day Dither-style writing chart from local aggregates.

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

The result is `dist/DiaryTranscription-1.2.0.dmg`.

The package script builds an ad-hoc-signed local app and copies SwiftPM resource bundles, including a colocated MLX Metal library, into the application. Test with:

```sh
swift test
```

## First-use setup

1. Open the menu-bar app and choose the folder that contains your Obsidian vault.
2. Choose **Install** for the 2.42 GB Cohere INT8 model. The first installation needs internet access.
3. Optionally open Settings to select a language or record a global shortcut. No shortcut is assigned by default; safe shortcuts require at least two modifiers, and Delete clears one.
4. Open **Resume / switch**, choose Diary, Blog, Notes, or Any file, then select new file, new folder + file, or continue existing.
5. Press the microphone, speak, and press Stop. The app transcribes locally and appends the result.
6. Choose **Open in Obsidian** to jump to the exact file that was saved.

## Yap into a blog and continue it later

1. In **Speak** or **Write**, choose **Resume / switch → Blog → New blog draft…** and name the file.
2. The app creates `<Vault>/Writing/Blogs/<name>.md` with `visibility: private` and `draft: true`.
3. Speak or type as many additions as you want. Existing text is never replaced.
4. On another day, pick the file under **Recent**, or choose **Continue existing file…**. The selection is remembered.
5. Review the draft in Obsidian. When it is genuinely public, set `visibility: public` and `draft: false`.
6. From the Quartz repository, run `npm run writing:export -- --vault "/Users/shariq/Documents/Obsidian Vault" --output "./content/notes"`, then preview and publish the site.

Daily `Diary/` logs are intentionally outside the public export. A blog draft only crosses into Quartz after the explicit public metadata change.

## Where everything goes

| Content                                                            | Location                                                          |
| ------------------------------------------------------------------ | ----------------------------------------------------------------- |
| Final diary notes                                                  | `<Your Vault>/Diary/diary-log_YYYY-MM-DD.md`                      |
| Private blog drafts                                                | `<Your Vault>/Writing/Blogs/<title>.md`                           |
| Private study and working notes                                    | `<Your Vault>/Notes/<title>.md`                                   |
| Pending recordings                                                 | `~/Library/Application Support/DiaryTranscription/Pending Audio/` |
| Downloaded model                                                   | `~/Library/Application Support/DiaryTranscription/Models/`        |
| Vault bookmark, language, shortcut, appearance, destination, stats | macOS `UserDefaults` for `com.shariq.DiaryTranscription`          |

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
