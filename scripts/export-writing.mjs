#!/usr/bin/env node

import { existsSync } from "node:fs"
import {
  copyFile,
  mkdir,
  readFile,
  readdir,
  rename,
  rm,
  stat,
  unlink,
  writeFile,
} from "node:fs/promises"
import path from "node:path"
import { pathToFileURL } from "node:url"
import { format as prettierFormat } from "prettier"
import YAML from "yaml"

const MANIFEST = ".writing-sync-manifest.json"

function parseMarkdown(text, sourcePath) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)([\s\S]*)$/)
  if (!match) return null
  const data = YAML.parse(match[1]) ?? {}
  if (typeof data !== "object" || Array.isArray(data)) {
    throw new Error(`${sourcePath} frontmatter must be a mapping`)
  }
  return { data, body: match[2] }
}

function renderMarkdown(data, body) {
  return `---\n${YAML.stringify(data).trimEnd()}\n---\n\n${body.replace(/^\s+/, "")}`
}

function safeSlug(value, sourcePath) {
  const slug = String(value)
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
  if (!slug) throw new Error(`${sourcePath} needs a filename or slug with letters or numbers`)
  return slug
}

function assertPublicSafe(text, sourcePath) {
  const checks = [
    ["private wikilink", /!?\[\[(?:Private(?:\/|\]|#)|Areas\/Private(?:\/|\]|#))/i],
    [
      "credential-like text",
      /\b(?:password|client[_ -]?secret|api[_ -]?key|private[_ -]?key|aws_access_key_id)\b\s*[:=]/i,
    ],
    ["private key", /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
  ]
  const finding = checks.find(([, pattern]) => pattern.test(text))
  if (finding) throw new Error(`${sourcePath} contains blocked ${finding[0]}`)
}

async function markdownFiles(directory) {
  if (!existsSync(directory)) return []
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue
    const entryPath = path.join(directory, entry.name)
    if (entry.isSymbolicLink()) continue
    if (entry.isDirectory()) files.push(...(await markdownFiles(entryPath)))
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(".md")) files.push(entryPath)
  }
  return files.sort()
}

async function previousGenerated(outputRoot) {
  const manifestPath = path.join(outputRoot, MANIFEST)
  if (!existsSync(manifestPath)) return []
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"))
  const generated = Array.isArray(manifest.generated) ? manifest.generated : []
  for (const item of generated) {
    if (typeof item !== "string" || !/^[a-z0-9][a-z0-9-]*\.md$/.test(item)) {
      throw new Error(`Writing manifest contains an unsafe generated path: ${item}`)
    }
  }
  return generated
}

async function atomicCopy(source, destination) {
  await mkdir(path.dirname(destination), { recursive: true })
  const temporary = `${destination}.writing-sync-${process.pid}-${Date.now()}`
  try {
    await copyFile(source, temporary)
    await rename(temporary, destination)
  } finally {
    await rm(temporary, { force: true })
  }
}

export async function exportWriting({ vaultRoot, outputRoot, dryRun = false }) {
  vaultRoot = path.resolve(vaultRoot)
  outputRoot = path.resolve(outputRoot)
  const writingRoot = path.join(vaultRoot, "Writing")
  if (!existsSync(vaultRoot) || !(await stat(vaultRoot)).isDirectory()) {
    throw new Error(`Vault not found: ${vaultRoot}`)
  }
  if (!existsSync(writingRoot) || !(await stat(writingRoot)).isDirectory()) {
    throw new Error(`Vault is missing Writing/: ${vaultRoot}`)
  }

  const stageRoot = path.join(
    path.dirname(outputRoot),
    `.writing-sync-stage-${process.pid}-${Date.now()}`,
  )
  await rm(stageRoot, { recursive: true, force: true })
  await mkdir(stageRoot, { recursive: true })

  try {
    const generated = []
    const seen = new Set()
    for (const sourcePath of await markdownFiles(writingRoot)) {
      const parsed = parseMarkdown(await readFile(sourcePath, "utf8"), sourcePath)
      if (!parsed) continue
      if (parsed.data.visibility !== "public" || parsed.data.draft !== false) continue
      if (parsed.data.kind !== "writing") {
        throw new Error(`${sourcePath} must set kind: writing`)
      }
      if (typeof parsed.data.title !== "string" || parsed.data.title.trim() === "") {
        throw new Error(`${sourcePath} must contain a non-empty title`)
      }
      if (!parsed.data.date) throw new Error(`${sourcePath} must contain a date`)

      const filename = path.basename(sourcePath, path.extname(sourcePath))
      const slug = safeSlug(parsed.data.slug ?? filename, sourcePath)
      const relativeTarget = `${slug}.md`
      if (relativeTarget === "index.md") {
        throw new Error(`${sourcePath} cannot use the reserved index slug`)
      }
      if (seen.has(relativeTarget)) {
        throw new Error(`More than one public writing draft resolves to ${relativeTarget}`)
      }
      seen.add(relativeTarget)

      const data = {
        ...parsed.data,
        kind: "writing",
        visibility: "public",
        draft: false,
      }
      const text = await prettierFormat(renderMarkdown(data, parsed.body), {
        parser: "markdown",
      })
      assertPublicSafe(text, sourcePath)
      await writeFile(path.join(stageRoot, relativeTarget), text)
      generated.push(relativeTarget)
    }
    generated.sort()

    const oldGenerated = await previousGenerated(outputRoot)
    for (const relativeTarget of generated) {
      const destination = path.join(outputRoot, relativeTarget)
      if (existsSync(destination) && !oldGenerated.includes(relativeTarget)) {
        throw new Error(`Refusing to replace handmade site note: ${destination}`)
      }
    }

    if (dryRun) return { files: generated.length, generated }
    await mkdir(outputRoot, { recursive: true })
    for (const relativeTarget of generated) {
      await atomicCopy(path.join(stageRoot, relativeTarget), path.join(outputRoot, relativeTarget))
    }
    for (const stale of oldGenerated.filter((item) => !generated.includes(item))) {
      const stalePath = path.join(outputRoot, stale)
      if (existsSync(stalePath)) await unlink(stalePath)
    }
    const manifestPath = path.join(outputRoot, MANIFEST)
    const temporaryManifest = `${manifestPath}.tmp-${process.pid}`
    await writeFile(
      temporaryManifest,
      `${JSON.stringify({ version: 1, generatedAt: new Date().toISOString(), generated }, null, 2)}\n`,
    )
    await rename(temporaryManifest, manifestPath)
    return { files: generated.length, generated }
  } finally {
    await rm(stageRoot, { recursive: true, force: true })
  }
}

function cliArgs(argv) {
  const args = { dryRun: false }
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index]
    if (item === "--dry-run") args.dryRun = true
    else if (item === "--vault") args.vaultRoot = argv[++index]
    else if (item === "--output") args.outputRoot = argv[++index]
    else throw new Error(`Unknown argument: ${item}`)
  }
  if (!args.vaultRoot || !args.outputRoot) {
    throw new Error(
      "Usage: export-writing --vault /path/to/vault --output /path/to/content/notes [--dry-run]",
    )
  }
  return args
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : ""
if (import.meta.url === invokedPath) {
  exportWriting(cliArgs(process.argv.slice(2)))
    .then((result) => console.log(`Writing export ready: ${result.files} public files.`))
    .catch((error) => {
      console.error(error instanceof Error ? error.message : error)
      process.exitCode = 1
    })
}
