# Garden Drop for macOS

Garden Drop is a private, local-first capture utility for a personal Obsidian vault. The current slice provides a native menu-bar entry, an optional notch hover surface, and a URL composer that writes captures locally before any network metadata or publication work.

## First slice

- Swift Package executable targeting macOS 14+.
- Native SwiftUI composer with SF Symbols and system typography.
- Permanent native menu-bar entry with a persisted optional notch shortcut.
- Native AppKit status item with a menu-bar menu.
- AppKit notch surface that begins at the physical top edge, with a measured 196pt bridge, 224pt compact peek, and 340pt drop composer.
- Click-to-expand capture zone accepting dropped links, files, and text alongside hand-entered notes and links.
- URL field accepting full links or hostnames and normalizing hostnames to HTTPS.
- Deterministic Markdown rendering for capture notes.
- Atomic note and attachment writes into a fixture vault.
- Tests for YAML frontmatter, wikilinks, attachments, and invalid vault names.

The app uses a fixture vault under the user's temporary directory by default. Set GARDEN_DROP_VAULT to point at a real Obsidian vault when manually exercising the writer.

## Run

```sh
swift test
swift run GardenDrop
```

The app starts as a menu-bar utility. Use **New Capture…** from the tray icon for the primary workflow. The menu and Settings both expose **Enable Notch Surface** as an optional shortcut.

- Menu Bar Only: the default for new installs.
- Menu Bar + Notch: hover the top-center notch, then click the compact peek to compose.

Legacy Notch-only preferences migrate to Menu Bar + Notch so the status item is restored automatically.

The notch interaction uses a 100ms hover dwell, 220ms ease-out reveal, 320ms click-to-compose morph, and 180ms collapse. A single persistent SwiftUI host crossfades content while the AppKit panel changes size, eliminating the extra resize between states. Reduce Motion switches the geometry changes to immediate state updates with a short content fade.

The composer opens with a dotted drop zone. Drop a URL or file, or choose **Add a link** / **Add a note** from the input field. Select an area, then choose **Plant** to write the capture locally. The menu-bar composer keeps the original full source → thought → area flow.

## Build an installable DMG

The release script builds a release Swift executable, wraps it in a macOS app bundle, ad-hoc signs it, and creates a drag-to-Applications DMG.

```sh
./scripts/build-dmg.sh
open dist/GardenDrop-0.4.2.dmg
```

To create an explicitly versioned build:

```sh
GARDEN_DROP_VERSION=0.2.1 ./scripts/build-dmg.sh
```

The DMG is intentionally ad-hoc signed for local testing. On first launch, macOS may require Control-click → Open. Installing a newer build means opening the new DMG and dragging Garden Drop into Applications again, replacing the previous copy.

The current build is still a local-first capture prototype; clipboard inspection, metadata enrichment, and nightly publication remain separate slices.

## Vault contract

The writer creates only these paths for a capture:

```text
Areas/<Area>/Captures/<capture-id>.md
Attachments/Captures/<capture-id>/<filename>
```

The generated note keeps the original source URL, the user's thought, the area wikilink, and optional captured text. It does not generate a summary.
