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
  landmark:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(1.45rem, 3vw, 1.85rem)"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.025em"
  body:
    fontFamily: "Manrope, system-ui, sans-serif"
    fontSize: "0.96rem"
    fontWeight: 400
    lineHeight: 1.75
  welcome:
    fontFamily: "Caveat, Segoe Print, cursive"
    fontSize: "clamp(2rem, 5vw, 2.8rem)"
    fontWeight: 600
    lineHeight: 1
  note:
    fontFamily: "Manrope, system-ui, sans-serif"
    fontSize: "0.82rem"
    fontWeight: 400
    lineHeight: 1.5
  path:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "1.03rem"
    fontWeight: 600
    lineHeight: 1.35
  metadata:
    fontFamily: "Caveat, Segoe Print, cursive"
    fontSize: "0.94rem"
    fontWeight: 600
    lineHeight: 1.4
  marginalia:
    fontFamily: "Caveat, Segoe Print, cursive"
    fontSize: "0.76rem / 0.82rem / 0.88rem / 0.9rem"
    fontWeight: 400
    lineHeight: 1.4
  quote:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "0.96rem / 1.05rem"
    fontWeight: 550
    lineHeight: 1.45
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

Fraunces gives headings a literary, slightly irregular character. Manrope keeps long technical notes clear. Caveat is reserved for welcomes, dates, and signoffs so the handwritten layer stays rare.

## Layout

Quartz keeps its wide desktop frame, but the persistent explorer and graph are removed. The left rail contains only identity, search, and theme controls. The center stays within a 46rem reading measure, expanding to 52rem on the home route. A restrained quote notebook occupies the homepage’s right rail on desktop and follows the article at narrower widths. Below 800px everything becomes a contained single column.

## Elevation & Depth

There are no cards or floating résumé surfaces. Depth comes from the framed garden window, paper tones, fine rules, and generous whitespace.

## Components

Garden paths and recent notes are compact botanical bullet trails, not cards. The quote rail is a ruled marginal list populated from Markdown frontmatter, with the newest collected lines first. The banner is a canvas-rendered pixel flower with restrained wind motion; the page background carries a five-cell cursor trail that slowly dims. Both become still when reduced motion is requested. Internal links use a rust underline. Article metadata and backlinks remain quiet supporting context on inner pages.

## Do’s and Don’ts

### Do:

- Let personal voice and internal links carry navigation.
- Keep notes visibly provisional through small maturity labels.
- Make factual work evidence available deeper in the garden.

### Don’t:

- Reintroduce a giant professional headline, CTA pair, metric strip, or project-card grid.
- Keep graph, explorer, and reader controls visible merely because Quartz provides them.
- Copy Jacky Zhao’s content, custom shader, or exact visual assets.
