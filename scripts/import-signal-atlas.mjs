#!/usr/bin/env node

import { mkdir, readFile, writeFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const DEFAULT_SOURCE =
  "https://raw.githubusercontent.com/shariqmalik10/signal-atlas/main/src/data/atlas.ts"
const CATEGORY_ORDER = [
  "Inspiration",
  "Reading",
  "Portfolios",
  "Components",
  "Motion & effects",
  "AI & agents",
  "Tools",
  "Collections",
]

const escapeHtml = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")

function collectionFromSource(source) {
  const marker = "export const COLLECTION_LINKS"
  const markerIndex = source.indexOf(marker)
  const assignment = source.indexOf("=", markerIndex)
  const start = source.indexOf("[", assignment)
  const end = source.lastIndexOf("]")
  if (markerIndex < 0 || assignment < 0 || start < 0 || end <= start) {
    throw new Error("Could not find COLLECTION_LINKS in the Signal Atlas source")
  }

  const collection = JSON.parse(source.slice(start, end + 1))
  if (!Array.isArray(collection)) throw new Error("COLLECTION_LINKS is not an array")
  return collection.filter(
    (entry) =>
      typeof entry?.title === "string" &&
      typeof entry?.url === "string" &&
      /^https?:\/\//i.test(entry.url) &&
      typeof entry?.category === "string",
  )
}

function renderPage(collection, sourceUrl) {
  const groups = new Map()
  for (const entry of collection) {
    const group = groups.get(entry.category) ?? []
    group.push(entry)
    groups.set(entry.category, group)
  }

  const categories = [
    ...CATEGORY_ORDER.filter((category) => groups.has(category)),
    ...[...groups.keys()].filter((category) => !CATEGORY_ORDER.includes(category)).sort(),
  ]

  const sections = categories.map((category) => {
    const entries = groups
      .get(category)
      .sort((left, right) => left.title.localeCompare(right.title, "en"))
    const items = entries
      .map(
        (entry) => `  <li><a href="${escapeHtml(entry.url)}">${escapeHtml(entry.title)}</a></li>`,
      )
      .join("\n")
    const open = category === "Inspiration" ? " open" : ""
    return `<details class="atlas-group"${open}>
<summary><span>${escapeHtml(category)}</span><small>${entries.length} links</small></summary>
<ul class="garden-link-list atlas-links">
${items}
</ul>
</details>`
  })

  return `---
title: Collected links
description: Blogs, tools, portfolios, and references Shariq Malik keeps for inspiration.
permalink: /inspiration
cssclasses:
  - inspiration-atlas
---

These are links I collect for inspiration and study. They are separate from [[notes/index|my own writing and notes]]. Start with <a href="/inspiration/blogs">blogs I return to</a> or <a href="/inspiration/design-interaction">saved design and interaction links</a>, then browse the fuller atlas below.

<p class="atlas-source">${collection.length} links synced from <a href="${escapeHtml(sourceUrl)}">Signal Atlas</a>.</p>

${sections.join("\n\n")}
`
}

async function loadSource(input) {
  if (/^https?:\/\//i.test(input)) {
    const response = await fetch(input)
    if (!response.ok) throw new Error(`Signal Atlas download failed: ${response.status}`)
    return response.text()
  }
  return readFile(path.resolve(input), "utf8")
}

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const source = process.argv[2] ?? DEFAULT_SOURCE
const output = path.join(projectRoot, "content", "inspiration", "index.md")
const collection = collectionFromSource(await loadSource(source))
await mkdir(path.dirname(output), { recursive: true })
await writeFile(output, renderPage(collection, DEFAULT_SOURCE))
console.log(`Wrote ${collection.length} links to ${path.relative(projectRoot, output)}`)
