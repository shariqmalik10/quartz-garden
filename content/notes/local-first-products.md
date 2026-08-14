---
title: Local-first changes the shape of a product
description: Notes from building Mouna around local data, attached evidence, and quiet interaction.
date: 2026-08-10
tags:
  - product-engineering
  - seedling
---

“Local-first” sounds like an infrastructure decision, but it changes the feel of a product.

While building [[projects/mouna|Mouna]], I wanted a grocery item to feel owned rather than rented from a service. Photographs, quantities, and expiry information stay with the person using the app. The photo is not decoration: it is evidence attached to the record.

That choice creates useful constraints. Capture has to be fast. Persistence has to be legible. Empty states matter because there is no remote catalogue pretending to know the user’s pantry already. Sync, if it arrives later, should extend ownership rather than become a prerequisite for it.

The result is quieter software. It can open without negotiating with a server, remember without demanding an account, and be useful before it becomes connected.

_Status: seedling. Next I want to write about spatial interaction as a memory aid._
