# Garden Drop for macOS

Garden Drop is a private, local-first capture utility for a personal Obsidian vault. The first slice is deliberately an ordinary macOS window: it proves the capture contract and file-writing behavior before the notch panel, clipboard inspection, and drag/drop surface are added.

## First slice

- Swift Package executable targeting macOS 14+.
- Native SwiftUI composer with SF Symbols and system typography.
- Deterministic Markdown rendering for capture notes.
- Atomic note and attachment writes into a fixture vault.
- Tests for YAML frontmatter, wikilinks, attachments, and invalid vault names.

The app uses a fixture vault under the user's temporary directory by default. Set GARDEN_DROP_VAULT to point at a real Obsidian vault when manually exercising the writer.

## Run

```sh
swift test
swift run GardenDrop
```

The current window is a temporary ordinary composer. The next implementation slice will add the capture source abstraction, clipboard activation, and an AppKit panel controller that can be anchored to a measured notch.

## Vault contract

The writer creates only these paths for a capture:

```text
Areas/<Area>/Captures/<capture-id>.md
Attachments/Captures/<capture-id>/<filename>
```

The generated note keeps the original source URL, the user's thought, the area wikilink, and optional captured text. It does not generate a summary.
