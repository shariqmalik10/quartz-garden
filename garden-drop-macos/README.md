# Garden Drop for macOS

Garden Drop is a private, local-first capture utility for a personal Obsidian vault. The current slice provides a native menu-bar entry, an optional notch hover surface, and a URL composer that writes captures locally before any network metadata or publication work.

## First slice

- Swift Package executable targeting macOS 14+.
- Native SwiftUI composer with SF Symbols and system typography.
- Persisted Notch, Menu Bar, or Both capture-surface selection.
- Native AppKit status item with a menu-bar menu.
- AppKit notch hover panel with a menu-bar fallback.
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

The app starts as a menu-bar utility. Open Capture Surface from the tray menu or Settings to choose:

- Notch: hover the top-center tracking region.
- Menu Bar: use Capture Now from the tray icon.
- Both: keep both entry points available.

The notch peek includes a settings button so switching away from Notch-only remains possible.

The composer starts with a sample link for visual testing. Replace it in **Link to capture**, add an optional thought, choose an area, and select **Save to Garden** or **Save Privately**.

## Build an installable DMG

The release script builds a release Swift executable, wraps it in a macOS app bundle, ad-hoc signs it, and creates a drag-to-Applications DMG.

```sh
./scripts/build-dmg.sh
open dist/GardenDrop-0.1.0.dmg
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
