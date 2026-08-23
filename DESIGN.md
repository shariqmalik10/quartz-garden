---
name: Shariq Malik - Working Garden
description: A warm, personal hypertext garden built on Quartz.
colors:
  paper: "#f5efe1"
  paper-deep: "#e8deca"
  ink: "#172b4d"
  body: "#40506b"
  faded: "#8b806d"
  rust: "#bd5438"
  sky: "#90a9c5"
  leaf: "#536d59"
  night: "#08172c"
typography:
  brand:
    fontFamily: "Nerko One, system-ui, sans-serif"
    fontSize: "clamp(1.7rem, 3vw, 2.15rem)"
    fontWeight: 400
    lineHeight: 1
  landmark:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(1.45rem, 3vw, 1.85rem)"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.025em"
  body:
    fontFamily: "Manrope, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.75
  welcome:
    fontFamily: "Playwrite GB J Guides, Segoe Print, cursive"
    fontSize: "clamp(2rem, 5vw, 2.8rem)"
    fontWeight: 400
    lineHeight: 1
  note:
    fontFamily: "Manrope, system-ui, sans-serif"
    fontSize: "0.88rem"
    fontWeight: 400
    lineHeight: 1.55
  path:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "1.03rem"
    fontWeight: 600
    lineHeight: 1.35
  metadata:
    fontFamily: "Manrope, system-ui, sans-serif"
    fontSize: "0.78rem"
    fontWeight: 400
    lineHeight: 1.4
  marginalia:
    fontFamily: "Playwrite GB J Guides, Segoe Print, cursive"
    fontSize: "1.75rem"
    fontWeight: 400
    lineHeight: 1.4
  quote:
    fontFamily: "Manrope, system-ui, sans-serif"
    fontSize: "0.92rem"
    fontWeight: 600
    lineHeight: 1.6
spacing:
  xs: "0.3rem"
  sm: "1rem"
  md: "1.5rem"
  lg: "3rem"
  xl: "4rem"
rounded:
  focus: "3px"
components:
  garden-window:
    backgroundColor: "{colors.sky}"
    textColor: "{colors.ink}"
    padding: "0"
  garden-path:
    backgroundColor: "transparent"
    textColor: "{colors.body}"
    padding: "1rem 0"
---

# Design System: Working Garden

## Overview

**Creative North Star: “The Working Garden”**

The site feels like a personal patch of the web rather than a formatted résumé. It borrows the quiet, literary rhythm of jzhao.xyz—serif landmarks, handwritten marginalia, warm paper, and conversational hyperlinks—while keeping Shariq’s own navy/rust palette and an abstract window of leaves and light.

**Key characteristics:** one generous reading column, sparse interface chrome, links embedded in prose, a softly interactive pixel field, a wind-bent pixel flower, visible work only after a welcoming introduction, and notes that can remain unfinished.

## Colors

Warm paper and navy ink make the site feel printed and lived-in. Rust is the second ink for underlines, focus, and handwritten moments. Sky and leaf tones appear only in the garden window.

## Typography

Nerko One is reserved for the compact Shariq Malik identity mark. Fraunces gives headings a literary, slightly irregular character, while Manrope carries body text, navigation, dates, and quotes at reading sizes. Playwrite GB J Guides appears only in the large welcome and signoff so the handwritten layer stays rare and legible.

## Layout

Quartz keeps its wide desktop frame, but the persistent explorer and graph are removed. The left rail contains only identity, search, and theme controls. The center stays within a 46rem reading measure, expanding to 52rem on the home route. A restrained quote notebook occupies the homepage’s right rail on desktop and follows the article at narrower widths. Below 800px everything becomes a contained single column.

## Elevation & Depth

There are no cards or floating résumé surfaces. Depth comes from the framed garden window, paper tones, fine rules, and generous whitespace.

## Components

Garden paths and recent notes are compact botanical trails, not cards. Public writing is date-sorted beneath the site identity without numbered labels; collected external links live in a separate, categorized atlas. The quote rail is a ruled marginal list populated from Markdown frontmatter, with the newest collected lines first and the full collection available in a native dialog drawer. The banner is a canvas-rendered pixel orb; the page background carries a five-cell cursor trail that slowly dims. Both become still when reduced motion is requested. Internal links use a rust underline. Article metadata and backlinks remain quiet supporting context on inner pages.

## Do’s and Don’ts

### Do:

- Let personal voice and internal links carry navigation.
- Keep notes visibly provisional through small maturity labels.
- Make factual work evidence available deeper in the garden.

### Don’t:

- Reintroduce a giant professional headline, CTA pair, metric strip, or project-card grid.
- Keep graph, explorer, and reader controls visible merely because Quartz provides them.
- Copy Jacky Zhao’s content, custom shader, or exact visual assets.
