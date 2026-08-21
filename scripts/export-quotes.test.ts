import assert from "node:assert/strict"
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { exportQuotes } from "./export-quotes.mjs"

async function fixture(visibility = "garden") {
  const root = await mkdtemp(path.join(os.tmpdir(), "quotes-export-"))
  const vaultRoot = path.join(root, "vault")
  const outputRoot = path.join(root, "quotes")
  await mkdir(path.join(vaultRoot, "Quotes", "Entries"), { recursive: true })
  await writeFile(
    path.join(vaultRoot, "Quotes", "Quotes.md"),
    `---\nkind: quote-collection\nvisibility: ${visibility}\ntitle: Quotes I collected\n---\n\n# Quotes\n`,
  )
  return { vaultRoot, outputRoot }
}

test("exports published quotes and skips drafts", async () => {
  const { vaultRoot, outputRoot } = await fixture()
  await writeFile(
    path.join(vaultRoot, "Quotes", "Entries", "kept-line.md"),
    `---\nkind: quote\nquote: A line worth keeping\npublish: true\n---\n`,
  )
  await writeFile(
    path.join(vaultRoot, "Quotes", "Entries", "private-draft.md"),
    `---\nkind: quote\nquote: Not yet public\npublish: false\n---\n`,
  )

  const result = await exportQuotes({ vaultRoot, outputRoot })
  assert.deepEqual(result.generated, ["index.md", "kept-line.md"])
  assert.match(
    await readFile(path.join(outputRoot, "kept-line.md"), "utf8"),
    /A line worth keeping/,
  )
})

test("refuses to export a private quote collection", async () => {
  const { vaultRoot, outputRoot } = await fixture("private")
  await assert.rejects(
    exportQuotes({ vaultRoot, outputRoot }),
    /must set visibility: garden before quotes can be published/,
  )
})
