import assert from "node:assert/strict"
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { exportWriting } from "./export-writing.mjs"

async function fixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "writing-export-"))
  const vaultRoot = path.join(root, "vault")
  const outputRoot = path.join(root, "site", "content", "notes")
  await mkdir(path.join(vaultRoot, "Writing"), { recursive: true })
  await mkdir(outputRoot, { recursive: true })
  await writeFile(path.join(outputRoot, "index.md"), "# Handmade index\n")
  return { vaultRoot, outputRoot }
}

function writing(title: string, visibility: "private" | "public", draft: boolean, body: string) {
  return `---\ntitle: "${title}"\ndate: 2026-08-24\nkind: writing\nvisibility: ${visibility}\ndraft: ${draft}\n---\n\n${body}\n`
}

test("exports only explicitly public writing and preserves the handmade notes index", async () => {
  const { vaultRoot, outputRoot } = await fixture()
  await writeFile(
    path.join(vaultRoot, "Writing", "My First Yap.md"),
    writing("My First Yap", "public", false, "The public thought."),
  )
  await writeFile(
    path.join(vaultRoot, "Writing", "private-draft.md"),
    writing("Private Draft", "private", true, "Never publish this."),
  )
  await mkdir(path.join(vaultRoot, "Writing", "Diary"), { recursive: true })
  await writeFile(
    path.join(vaultRoot, "Writing", "Diary", "diary-log.md"),
    "# Private diary without frontmatter\n",
  )

  const result = await exportWriting({ vaultRoot, outputRoot })

  assert.deepEqual(result.generated, ["my-first-yap.md"])
  assert.match(await readFile(path.join(outputRoot, "my-first-yap.md"), "utf8"), /public thought/)
  assert.equal(await readFile(path.join(outputRoot, "index.md"), "utf8"), "# Handmade index\n")
  await assert.rejects(readFile(path.join(outputRoot, "private-draft.md")), /ENOENT/)
})

test("cleans only previously generated writing files", async () => {
  const { vaultRoot, outputRoot } = await fixture()
  await writeFile(
    path.join(vaultRoot, "Writing", "first.md"),
    writing("First", "public", false, "First version."),
  )
  await exportWriting({ vaultRoot, outputRoot })
  await writeFile(
    path.join(vaultRoot, "Writing", "first.md"),
    writing("First", "private", true, "Now private."),
  )
  await writeFile(path.join(outputRoot, "handmade.md"), "# Keep me\n")

  const result = await exportWriting({ vaultRoot, outputRoot })

  assert.deepEqual(result.generated, [])
  await assert.rejects(readFile(path.join(outputRoot, "first.md")), /ENOENT/)
  assert.equal(await readFile(path.join(outputRoot, "handmade.md"), "utf8"), "# Keep me\n")
})

test("validates every public draft before mutating site notes", async () => {
  const { vaultRoot, outputRoot } = await fixture()
  await writeFile(
    path.join(vaultRoot, "Writing", "unsafe.md"),
    writing("Unsafe", "public", false, "api_key = do-not-publish"),
  )

  await assert.rejects(
    exportWriting({ vaultRoot, outputRoot }),
    /contains blocked credential-like text/,
  )
  assert.equal(await readFile(path.join(outputRoot, "index.md"), "utf8"), "# Handmade index\n")
})
