import assert from "node:assert/strict"
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { auditVault } from "./audit-vault.mjs"

async function note(file: string, frontmatter: string, body = "") {
  await mkdir(path.dirname(file), { recursive: true })
  await writeFile(file, `---\n${frontmatter}\n---\n\n${body}\n`)
}

async function baseVault() {
  const vault = await mkdtemp(path.join(os.tmpdir(), "vault-audit-"))
  await note(
    path.join(vault, "Areas", "Design", "Design.md"),
    "kind: area\nvisibility: garden\nsite_slug: inspiration/design",
  )
  await note(path.join(vault, "Quotes", "Quotes.md"), "kind: quote-collection\nvisibility: garden")
  await mkdir(path.join(vault, "Writing"), { recursive: true })
  return vault
}

test("marks private drafts as skipped and public writing as included", async () => {
  const vault = await baseVault()
  try {
    await note(
      path.join(vault, "Writing", "draft.md"),
      "kind: writing\ntitle: ''\nvisibility: private\ndraft: true",
    )
    await note(
      path.join(vault, "Writing", "public.md"),
      "kind: writing\ntitle: Public\ndate: 2026-09-19\nvisibility: public\ndraft: false",
    )

    const report = await auditVault(vault)
    assert.equal(report.ok, true)
    assert.equal(report.records.find(({ path }) => path === "Writing/draft.md")?.status, "skipped")
    assert.equal(
      report.records.find(({ path }) => path === "Writing/public.md")?.status,
      "included",
    )
  } finally {
    await rm(vault, { recursive: true, force: true })
  }
})

test("blocks every capture that resolves to a duplicate public target", async () => {
  const vault = await baseVault()
  try {
    for (const filename of ["one.md", "two.md"]) {
      await note(
        path.join(vault, "Areas", "Design", "Captures", filename),
        "id: duplicate\nkind: capture\ntitle: Duplicate",
      )
    }

    const report = await auditVault(vault)
    const duplicates = report.records.filter(({ reason }) =>
      reason?.includes("duplicate public target"),
    )
    assert.equal(report.ok, false)
    assert.equal(duplicates.length, 2)
    assert.ok(duplicates.every(({ status }) => status === "blocked"))
  } finally {
    await rm(vault, { recursive: true, force: true })
  }
})
