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
    fontFamily: "SF Pro Display, system-ui, sans-serif"
    fontSize: "14pt"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "13pt"
    fontWeight: 400
    lineHeight: 1.35
  metadata:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 400
    lineHeight: 1.25
  label:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
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
OWN-WORLD: SF Pro, system materials, night navy structure, rust action, leaf confirmation, one quiet surface, and compact SF Symbols.
STORY: A copied source becomes a thought in the right area; the user can see where it will land before saving.
FIRST VIEWPORT: A 420-point composer begins with the source preview, keeps the thought field central, and ends with one visibility-aware Save action.
FORM: The notch is the origin: a black bridge begins at the physical screen edge, then grows into a drop zone where a link, file, or note can be planted.
-->

# Design System: Garden Drop Native Surface

## Overview

Garden Drop is an opening in the vault, not another place to manage work. The interface borrows the physical relationship of a native macOS sheet: quiet while idle, attached to the top edge when active, and clear about the destination before the user commits a thought.

The capture surface is native and quiet while idle: the menu-bar status item is always present, while the top-center notch is an optional shortcut. The durable surface language is one system-material surface, SF Pro hierarchy, monochrome SF Symbols, and Garden colors reserved for action, status, and confirmation. The notch preference persists across launches without ever removing the primary menu-bar route.

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

**Display Font:** SF Pro Display (system fallback)
**Body Font:** SF Pro Text (system fallback)
**Label/Mono Font:** None; use the system UI family throughout.

**Character:** Compact, highly legible, and native to macOS. The utility does not use the website's Fraunces or Caveat treatments in controls because scanability matters more than editorial expression here.

### Hierarchy

- **Source title** (semibold, 14pt, 1.2): The two-line source preview.
- **Body** (regular, 13pt, 1.35): Thought field and explanatory copy.
- **Metadata** (regular, 11pt, 1.25): Domain, dimensions, vault health, and shortcut hints.
- **Label** (medium, 13pt, 1.25): Area and primary action labels.

## Layout

The composer is a single 420pt-wide surface with 14pt outer padding and 10pt grouping rhythm. The source preview reserves its media bounds before metadata arrives. The thought field grows from 44pt to a maximum of 96pt. The footer keeps status at left and the one primary action at right.

The notch state borrows the measured rhythm of the reference app: a 196pt × 32pt black bridge at the physical top edge, a 224pt × 48pt compact peek with its controls below the 32pt hardware band, and a 340pt × 500pt capture surface that grows from the same Y=0 origin. One persistent hosting surface owns all three states so frame motion remains monotonic while content fades and scales in place. The idle-to-peek reveal uses a 100ms dwell and a 220ms ease-out expansion; collapse takes 180ms, the expanded composer arrives over 320ms, and close takes 220ms. Its dotted drop zone accepts links, files, and text, while the bottom field accepts a note or link by hand. The menu-bar route is always present and contains New Capture, Enable Notch Surface, Settings, and Quit.

## Elevation & Depth

Depth comes from native window material and a single soft panel shadow rather than nested cards. The material does not animate its blur. Reduced Transparency switches the surface to an opaque system background while preserving the same hierarchy.

## Shapes

The capture sheet has 16pt lower corners. Compact fields and action controls use an 8pt radius and retain native focus rings. Separators are one-pixel system rules. Icon buttons keep a minimum 44pt target where the platform allows it; their glyphs remain monochrome or hierarchical.

## Components

### Source preview

The source is the first reading unit: representative image or source icon, editable link, domain/type metadata, and quiet replace/open actions. It never becomes a decorative card.

### Thought field

The field is a multiline native editor with the prompt “Why did this catch your eye?” It keeps entered text on errors and accepts Obsidian wikilinks without reformatting them.

### Area selector

The row combines an SF Symbol, area name, visibility word, and chevron. The eventual picker is a native anchored popover with search, recent areas, Garden/private sections, and Create new area.

### Capture surface selector

Settings and the menu-bar menu expose one explicit toggle: Enable Notch Surface. Menu-bar capture remains available in either state, and legacy Notch-only preferences migrate to Menu Bar + Notch.

### Primary action

The action reads “Save to Garden” or “Save Privately,” shows a native saving state, and keeps the visibility meaning in copy and iconography as well as color.

### Success and error states

Success contracts into a short planted marker and a destination-aware confirmation. Errors remain inline, name the recovery, and never shake or discard the form.

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
