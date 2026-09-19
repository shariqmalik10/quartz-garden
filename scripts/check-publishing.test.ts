import assert from "node:assert/strict"
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { checkPublishing, formatPublishingReport } from "./check-publishing.mjs"

async function note(file: string, frontmatter: string, body = "") {
  await mkdir(path.dirname(file), { recursive: true })
  await writeFile(file, `---\n${frontmatter}\n---\n\n${body}\n`)
}

async function fixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "publishing-check-"))
  const vaultRoot = path.join(root, "vault")
  const siteRoot = path.join(root, "site")

  await note(
    path.join(vaultRoot, "Areas", "Design", "Design.md"),
    [
      "kind: area",
      "visibility: garden",
      "site_slug: inspiration/design",
      "media_policy: reference",
    ].join("\n"),
    "A public area.",
  )
  await note(
    path.join(vaultRoot, "Quotes", "Quotes.md"),
    "kind: quote-collection\nvisibility: garden",
    "# Quotes",
  )
  await mkdir(path.join(vaultRoot, "Writing"), { recursive: true })
  await mkdir(path.join(siteRoot, "content", "notes"), { recursive: true })

  return { root, vaultRoot, siteRoot }
}

test("reports all three publication collections without mutating site content", async () => {
  const { root, vaultRoot, siteRoot } = await fixture()
  try {
    const report = await checkPublishing({ vaultRoot, siteRoot })

    assert.equal(report.ok, true)
    assert.deepEqual(
      report.collections.map(({ key, status }) => [key, status]),
      [
        ["garden", "ready"],
        ["quotes", "ready"],
        ["writing", "ready"],
      ],
    )
    assert.match(formatPublishingReport(report), /Publication check passed/)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test("reports every collection even when one is blocked", async () => {
  const { root, vaultRoot, siteRoot } = await fixture()
  try {
    await note(
      path.join(vaultRoot, "Writing", "unsafe.md"),
      [
        "kind: writing",
        "title: Unsafe draft",
        "date: 2026-09-19",
        "visibility: public",
        "draft: false",
      ].join("\n"),
      "api_key = do-not-publish",
    )

    const report = await checkPublishing({ vaultRoot, siteRoot })

    assert.equal(report.ok, false)
    assert.equal(report.collections.find(({ key }) => key === "writing")?.status, "blocked")
    assert.equal(report.collections.find(({ key }) => key === "garden")?.status, "ready")
    assert.equal(report.collections.find(({ key }) => key === "quotes")?.status, "ready")
    assert.match(formatPublishingReport(report), /credential-like text/)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
