import assert from "node:assert/strict"
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"
import { exportGarden } from "./export-garden.mjs"

async function note(file: string, frontmatter: Record<string, unknown>, body = "") {
  await mkdir(path.dirname(file), { recursive: true })
  const yaml = Object.entries(frontmatter)
    .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
    .join("\n")
  await writeFile(file, `---\n${yaml}\n---\n\n${body}\n`)
}

async function fixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "garden-export-"))
  const vault = path.join(root, "vault")
  const output = path.join(root, "site", "content", "garden-sync")
  await mkdir(vault, { recursive: true })
  return { root, vault, output }
}

test("exports garden areas, redacts private links, and excludes private captures", async () => {
  const { root, vault, output } = await fixture()
  try {
    await note(
      path.join(vault, "Areas", "Design", "Design.md"),
      {
        kind: "area",
        visibility: "garden",
        site_slug: "inspiration/design",
        media_policy: "reference",
      },
      "Public map. [[Personal]]",
    )
    await note(
      path.join(vault, "Areas", "Personal", "Personal.md"),
      {
        kind: "area",
        visibility: "private",
        site_slug: "private/personal",
        media_policy: "reference",
      },
      "Private map",
    )
    await note(
      path.join(vault, "Areas", "Design", "Captures", "one.md"),
      {
        id: "gd-one",
        kind: "capture",
        title: "One",
        attachments: ["[[Attachments/Captures/gd-one/preview.webp]]"],
      },
      "A thought. [[Areas/Personal/Personal]] ![[Attachments/Captures/gd-one/preview.webp]]",
    )
    await note(
      path.join(vault, "Areas", "Personal", "Captures", "secret.md"),
      { id: "gd-secret", kind: "capture", title: "Secret" },
      "Never publish",
    )

    const result = await exportGarden({ vaultRoot: vault, outputRoot: output })
    assert.equal(result.areas, 1)
    const capture = await readFile(path.join(output, "inspiration", "design", "gd-one.md"), "utf8")
    assert.match(capture, /publish: true/)
    assert.match(capture, /permalink: \/inspiration\/design\/gd-one/)
    assert.match(capture, /\[private reference omitted\]/)
    assert.match(capture, /\[source media omitted\]/)
    await assert.rejects(readFile(path.join(output, "private", "personal", "gd-secret.md"), "utf8"))
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test("fails before mutating output when public content contains sensitive data", async () => {
  const { root, vault, output } = await fixture()
  try {
    await note(
      path.join(vault, "Areas", "Design", "Design.md"),
      { kind: "area", visibility: "garden", site_slug: "design", media_policy: "reference" },
      "Safe map",
    )
    await note(
      path.join(vault, "Areas", "Design", "Captures", "one.md"),
      { id: "gd-one", kind: "capture", title: "One" },
      "Contact me at person@example.com",
    )
    await mkdir(output, { recursive: true })
    await writeFile(path.join(output, "handmade.md"), "keep me")

    await assert.rejects(
      exportGarden({ vaultRoot: vault, outputRoot: output }),
      /blocked email address/,
    )
    assert.equal(await readFile(path.join(output, "handmade.md"), "utf8"), "keep me")
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test("rejects path traversal", async () => {
  const { root, vault, output } = await fixture()
  try {
    await note(
      path.join(vault, "Areas", "Design", "Design.md"),
      { kind: "area", visibility: "garden", site_slug: "../escape", media_policy: "reference" },
      "Map",
    )
    await assert.rejects(
      exportGarden({ vaultRoot: vault, outputRoot: output }),
      /safe relative path/,
    )
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test("manifest cleanup removes stale generated files and preserves handmade files", async () => {
  const { root, vault, output } = await fixture()
  try {
    await note(
      path.join(vault, "Areas", "Design", "Design.md"),
      { kind: "area", visibility: "garden", site_slug: "design", media_policy: "reference" },
      "Map",
    )
    await mkdir(path.join(output, "old"), { recursive: true })
    await writeFile(path.join(output, "old", "stale.md"), "stale")
    await writeFile(path.join(output, "handmade.md"), "keep me")
    await writeFile(
      path.join(output, ".garden-sync-manifest.json"),
      JSON.stringify({ generated: ["old/stale.md"] }),
    )

    await exportGarden({ vaultRoot: vault, outputRoot: output })
    await assert.rejects(readFile(path.join(output, "old", "stale.md"), "utf8"))
    assert.equal(await readFile(path.join(output, "handmade.md"), "utf8"), "keep me")
    assert.match(await readFile(path.join(output, "design", "index.md"), "utf8"), /publish: true/)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
