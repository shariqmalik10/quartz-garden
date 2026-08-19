---
name: Garden Drop Native Surface
description: A calm macOS capture sheet for planting links, images, and text into a private Obsidian vault.
colors:
  night: "#08172C"
  rust: "#BD5438"
  leaf: "#536D59"
  sky: "#90A9C5"
  paper: "#F5EFE1"
  system-red: "#FF453A"
typography:
  source-title:
    fontFamily: "SF Pro Rounded, system-ui, sans-serif"
    fontSize: "14pt"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro Rounded, system-ui, sans-serif"
    fontSize: "13pt"
    fontWeight: 400
    lineHeight: 1.35
  metadata:
    fontFamily: "SF Pro Rounded, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 400
    lineHeight: 1.25
  label:
    fontFamily: "SF Pro Rounded, system-ui, sans-serif"
    fontSize: "13pt"
    fontWeight: 500
    lineHeight: 1.25
rounded:
  field: "8pt"
  sheet: "16pt"
  icon-hit-area: "8pt"
spacing:
  compact: "8pt"
  content: "10pt"
  outer: "14pt"
components:
  primary-action:
    backgroundColor: "{colors.rust}"
    textColor: "{colors.paper}"
    rounded: "{rounded.field}"
    padding: "8pt 14pt"
  thought-field:
    backgroundColor: "transparent"
    textColor: "{colors.night}"
    rounded: "{rounded.field}"
    padding: "8pt"
---

<!--
THESIS: Garden Drop is a small native sheet attached to an existing macOS scene, not a dashboard or a permanent window.
OWN-WORLD: SF Pro Rounded, system materials, night navy structure, rust action, leaf confirmation, one quiet surface, and compact SF Symbols.
STORY: A copied source becomes a thought in the right area; the user can see where it will land before saving.
FIRST VIEWPORT: A compact 312-point composer begins with a source/drop row, keeps the thought field central, and ends with one visibility-aware Save action.
FORM: The notch is the origin: a black bridge begins at the physical screen edge, then grows into a drop zone where a link, file, or note can be planted.
-->

# Design System: Garden Drop Native Surface

## Overview

Garden Drop is an opening in the vault, not another place to manage work. The interface borrows the physical relationship of a native macOS sheet: quiet while idle, attached to the top edge when active, and clear about the destination before the user commits a thought.

The capture surface is native and quiet while idle: the menu-bar status item is always present, while the top-center notch is an optional shortcut. The durable surface language is one system-material surface, SF Pro Rounded hierarchy, monochrome SF Symbols, and Garden colors reserved for action, status, and confirmation. The notch preference persists across launches without ever removing the primary menu-bar route.

**Key Characteristics:**

- One surface with a clear source → thought → area → save order.
- Native controls and focus behavior before expressive ornament.
- Garden personality carried by rust, leaf, sky, and the planting vocabulary.
- No idle capsule, dashboard cards, decorative loops, or pixel-art controls.

## Colors

Night navy gives the structural surface a stable anchor; paper, rust, leaf, and sky carry meaning sparingly so privacy and success never depend on hue alone.

### Primary

- **Rust action** (#BD5438): Primary save and active capture affordances.
- **Leaf confirmation** (#536D59): Successful local writes and planted-state confirmation.

### Secondary

- **Sky metadata** (#90A9C5): Loading, duplicate, and supporting status cues.

### Neutral

- **Night structure** (#08172C): Notch cap, dark structural text, and high-contrast anchors.
- **Warm paper** (#F5EFE1): Light appearance tint and authored Garden reference surface.
- **System red** (#FF453A): Native error state only.

**The Meaning-Beyond-Color Rule.** Every Garden/private, success/error, and loading state includes text or an icon that carries the meaning without color.

## Typography

**Display Font:** SF Pro Rounded through SwiftUI's `.rounded` system design
**Body Font:** SF Pro Rounded through SwiftUI's `.rounded` system design
**Label/Mono Font:** None; use the system UI family throughout.

**Character:** Compact, highly legible, and native to macOS. The utility does not use the website's Fraunces or Caveat treatments in controls because scanability matters more than editorial expression here.

### Hierarchy

- **Source title** (semibold, 14pt, 1.2): The two-line source preview.
- **Body** (regular, 13pt, 1.35): Thought field and explanatory copy.
- **Metadata** (regular, 11pt, 1.25): Domain, dimensions, vault health, and shortcut hints.
- **Label** (medium, 13pt, 1.25): Area and primary action labels.

## Layout

The notch composer is a single 312pt-wide surface with a 412pt normal frame and 14pt horizontal content padding. It is a vertical capture path rather than a dashboard: header/status, source/drop, thought, destination/privacy, inline status, then one full-width save action. The source/drop row is approximately 64pt tall. The thought editor is multiline and remains visually central; it uses a compact fixed editing region so the save action stays in the first viewport.

The notch state borrows the measured rhythm of the reference app: a 196pt × 32pt black bridge at the physical top edge, a 224pt × 46pt compact peek with its controls below the hardware band, and a 312pt × 412pt composer that grows from the same Y=0 origin. Error copy expands the panel to the shared 312pt × 448pt frame without moving the hierarchy. One persistent hosting surface owns all states so frame motion remains monotonic while content changes in place. The idle-to-peek reveal uses a 100ms dwell and a 220ms single-frame resize; composer resize uses the shared 300ms duration; collapse takes 180ms and close takes 220ms. The source row accepts files, URLs, and text by drag and drop; when no source exists it also exposes a source TextField for pasted links or text.

The safe top inset remains visually empty so readable controls begin below the physical notch band. The source, thought, destination, status, and save regions use restrained dark fields and one-pixel outlines; there are no dotted canvases, nested cards, decorative gradients, or scale-based transitions.

## Elevation & Depth

Depth comes from native window material and a single soft panel shadow rather than nested cards. The material does not animate its blur. Reduced Transparency switches the surface to an opaque system background while preserving the same hierarchy.

## Shapes

The capture sheet has 16pt lower corners. Compact fields and action controls use an 8pt radius and retain native focus rings. Separators are one-pixel system rules. Icon buttons keep a minimum 44pt target where the platform allows it; their glyphs remain monochrome or hierarchical.

## Components

### Source preview

The source/drop row is the first reading unit: a representative SF Symbol, current source title, domain/type or file metadata, and a quiet ready marker. A blank composer shows a compact source TextField. Files, URLs, and text can be dropped on the whole row; dropped text becomes a link when valid or is appended to the thought.

### Thought field

The field is a multiline native editor with the prompt “Why did this catch your eye?” It keeps entered text on errors and accepts Obsidian wikilinks without reformatting them.

### Area selector

The destination row combines an SF Symbol, area name, explicit Garden/Private visibility word, and chevron. The picker is a native anchored menu using the available areas; privacy is communicated in text and iconography as well as color.

### Capture surface selector

Settings and the menu-bar menu expose one explicit toggle: Enable Notch Surface. Menu-bar capture remains available in either state, and legacy Notch-only preferences migrate to Menu Bar + Notch.

### Overflow menu

The composer keeps less-common actions behind the ellipsis: Settings, Clear draft, and Open vault. Source input is automatic—links and text share one field—so a separate input-mode control is not needed in the compact surface.

### Primary action

The full-width action reads “Save to Garden” or “Save Privately,” shows “Saving…” while the writer is active, and keeps the visibility meaning in copy and iconography as well as color. Cmd-Return invokes the same action.

### Success and error states

The composer state model is explicit: empty, prepared, saving, done, and error. Empty and prepared states keep the status line legible; saving disables destructive navigation and shows a local-write indicator; done shows a leaf confirmation and destination-aware copy, then closes after a readable 1.25-second hold. Errors remain inline, expand the panel to 448pt, name the failure, preserve all entered content, and leave the save action available for retry.

## Focus, motion, and dismissal

Focus is local to the composer through an enum-backed `@FocusState` with `source` and `thought` cases. A blank composer focuses the source field after the opening resize settles; a composer opened with an initial source focuses the thought editor. Focus is not repeatedly changed during the opening animation. Reduce Motion removes decorative feedback animation and uses the controller's short non-animated resize path; normal feedback uses opacity, border, trim, and a subtle saving-indicator rotation, with no scale effects or staggered reveals.

Cmd-Return saves. Escape and the close button close immediately only when the draft is clean. A dirty draft presents a discard confirmation, while close and discard remain unavailable during saving so a write cannot be interrupted by an accidental dismissal.

## Do's and Don'ts

### Do:

- **Do** let the source, thought, area, and save action be understandable within two seconds.
- **Do** follow Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver, and keyboard navigation.
- **Do** keep the hidden state free of timers, rendering loops, and clipboard polling.
- **Do** reserve Garden color for action, status, and confirmation.
- **Do** keep the menu-bar route installed at all times and treat the notch as an optional companion.

### Don't:

- **Don't** put readable controls inside the physical notch band; the black bridge may merge with it, but text and actions begin below the measured safe-area inset.
- **Don't** use stacked glass cards, decorative gradients, pixel fonts, or handwritten controls.
- **Don't** make capture wait on network metadata, GitHub, or publication.
- **Don't** communicate privacy or errors with color alone.
