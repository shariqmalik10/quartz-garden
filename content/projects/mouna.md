---
title: Mouna
description: A local-first spatial grocery memory for iPhone and Mac.
tags:
  - project
  - swiftui
  - local-first
---

[View source on GitHub](https://github.com/shariqmalik10/whats-in-my-fridge)

Mouna turns grocery photographs into tactile pantry objects. Instead of presenting inventory as a spreadsheet, it places photographic cutouts on a pan-and-zoom canvas and keeps quantity, expiry, nutrition, purchase details, and evidence connected to each item.

## What the system does

- Runs on iOS 17+ and macOS 14+ with SwiftUI and SwiftData.
- Normalizes photographs and performs foreground isolation, OCR, and barcode recognition on device.
- Tracks storage location, quantity, consumption, expiry, evidence, and lifecycle actions.
- Keeps inventory and photographs inside the local app container; only a valid barcode may be sent to Open Food Facts over HTTPS.
- Includes opt-in demonstration data, reduced-motion handling, defensive archive logic, and unit/UI tests.

## Why it matters

Mouna is an end-to-end product exercise: data modeling, image processing, persistence, privacy boundaries, spatial interaction, failure handling, and accessibility all meet in one interface. The repository is deliberately reproducible for simulator evaluation and honest about what still requires a physical iPhone.

Related: [[../areas/product-engineering|Product engineering]] · [[../areas/applied-ml|Applied ML]]
