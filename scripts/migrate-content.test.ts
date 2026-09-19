import assert from "node:assert/strict"
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { migrateFrontmatter, migrationReport } from "./migrate-content.mjs"

test("migrates a legacy published writing flag without losing metadata", () => {
  const result = migrateFrontmatter({
    kind: "writing",
    title: "Legacy",
    published: true,
    custom: "keep",
  })
  assert.deepEqual(result.data, {
    kind: "writing",
    title: "Legacy",
    custom: "keep",
    visibility: "public",
    draft: false,
    contract_version: 1,
  })
})

test("migration report is a dry run unless write is explicit", async () => {
  const vault = await mkdtemp(path.join(os.tmpdir(), "content-migration-"))
  const source = path.join(vault, "Quotes", "Entries", "legacy.md")
  const original = "---\nkind: quote\nquote: Keep this\ndate: 2026-09-19\npublish: true\n---\n"
  try {
    await mkdir(path.dirname(source), { recursive: true })
    await writeFile(source, original)
    const report = await migrationReport({ vaultRoot: vault })

    assert.equal(report.files, 1)
    assert.equal(report.records[0].status, "would-migrate")
    assert.equal(await readFile(source, "utf8"), original)
  } finally {
    await rm(vault, { recursive: true, force: true })
  }
})

test("version-only migration preserves the original frontmatter and body formatting", async () => {
  const vault = await mkdtemp(path.join(os.tmpdir(), "content-migration-format-"))
  const source = path.join(vault, "Areas", "Design", "Design.md")
  const original =
    "---\nkind: area\nvisibility: garden\nsite_slug: inspiration/design\ntags: [one, two]\n---\n\nOriginal body.\n"
  try {
    await mkdir(path.dirname(source), { recursive: true })
    await writeFile(source, original)
    await migrationReport({ vaultRoot: vault, write: true })

    assert.equal(
      await readFile(source, "utf8"),
      original.replace(/^---\n/, "---\ncontract_version: 1\n"),
    )
  } finally {
    await rm(vault, { recursive: true, force: true })
  }
})
