---
title: Signal Atlas
description: A contextual directory for design-engineering resources.
tags:
  - project
  - react
  - design-engineering
---

[View source on GitHub](https://github.com/shariqmalik10/signal-atlas)

Signal Atlas is a public field guide to useful corners of the design-engineering internet. Its source-controlled collection currently contains 365 resources gathered from multiple curated trails.

## The interaction model

- Search scores titles, tags, and contextual descriptions rather than acting as a plain string filter.
- Category filters and a command palette support both browsing and direct retrieval.
- Optional hover previews let visitors inspect a destination without interrupting the directory.
- Every resource row remains a real new-tab link, with keyboard focus and a non-interactive preview layer.
- The project includes Vitest and Testing Library coverage for search, filtering, previews, and keyboard behavior.

Built with React 19, TypeScript, Vite, `cmdk`, and a deliberately source-controlled data model.

Related: [[../areas/product-engineering|Product engineering]]
