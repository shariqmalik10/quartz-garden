---
version: 1
slug: "garden-studio-app-page-tsx"
primary_target: "garden-studio/app/page.tsx"
related_targets:
  [
    "garden-studio/app/globals.css",
    "garden-studio/components/studio-shell.tsx",
    "garden-studio/components/item-ledger.tsx",
  ]
---

# Garden Studio · Overview

## Purpose

Private, read-only operating surface for checking vault content and its route into the public Quartz garden. The user should know within one viewport whether the source is connected, how many items sit in each publishing state, and what changed recently.

## Visual direction

Treat the surface as the garden's back room: a compact publishing ledger, not a generic analytics dashboard. Preserve the public site's warm paper, navy ink, rust accent, leaf green, and restrained serif landmarks. Favor ruled rows, field labels, and editorial density over detached cards.

## Structure

- Sticky navigation rail on wide screens; compact horizontal navigation on narrow screens.
- Source health strip immediately after the page heading.
- Collection ledger as the primary task surface.
- Recent items below; commit activity as a supporting rail.
- Read-only status must remain clear on item and health views.

## Interaction and accessibility

Use familiar links, buttons, search, and select controls. Keep visible focus, skip navigation, semantic headings, status text that does not rely on color, 44px-class primary targets, responsive ledgers, and reduced-motion support. No vault token or private content may reach the client unless rendered for the authenticated session.
