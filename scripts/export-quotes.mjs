#!/usr/bin/env node

import { existsSync } from "node:fs"
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises"
import path from "node:path"
import { pathToFileURL } from "node:url"
import { format as prettierFormat } from "prettier"
import YAML from "yaml"

const MANIFEST = ".quotes-sync-manifest.json"

function parseMarkdown(text, sourcePath) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)([\s\S]*)$/)
  if (!match) throw new Error(`${sourcePath} must begin with YAML frontmatter`)
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
  const slug = String(value).trim()
  if (!/^[a-z0-9][a-z0-9-]*$/i.test(slug)) {
    throw new Error(`${sourcePath} slug must contain only letters, numbers, and hyphens`)
  }
  return slug
}

function assertPublicSafe(text, sourcePath) {
  const checks = [
    ["email address", /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i],
    ["LinkedIn reference", /\blinkedin\.com\b/i],
    ["resume reference", /\b(?:resume|résumé)\b/i],
    ["private wikilink", /!?\[\[(?:Private(?:\/|\]|#)|Areas\/Private(?:\/|\]|#))/i],
    [
      "credential-like text",
      /\b(?:password|client[_ -]?secret|api[_ -]?key|private[_ -]?key)\b\s*[:=]/i,
    ],
  ]
  const finding = checks.find(([, pattern]) => pattern.test(text))
  if (finding) throw new Error(`${sourcePath} contains blocked ${finding[0]}`)
}

async function quoteFiles(directory) {
  if (!existsSync(directory)) return []
  return (await readdir(directory, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".md"))
    .map((entry) => path.join(directory, entry.name))
    .sort()
}

export async function exportQuotes({ vaultRoot, outputRoot, dryRun = false }) {
  vaultRoot = path.resolve(vaultRoot)
  outputRoot = path.resolve(outputRoot)
  const quotesRoot = path.join(vaultRoot, "Quotes")
  const mapPath = path.join(quotesRoot, "Quotes.md")
  if (!existsSync(vaultRoot) || !(await stat(vaultRoot)).isDirectory()) {
    throw new Error(`Vault not found: ${vaultRoot}`)
  }
  if (!existsSync(mapPath)) throw new Error(`Vault is missing Quotes/Quotes.md: ${vaultRoot}`)

  const map = parseMarkdown(await readFile(mapPath, "utf8"), mapPath)
  if (map.data.kind !== "quote-collection") {
    throw new Error(`${mapPath} must set kind: quote-collection`)
  }
  if (map.data.visibility !== "garden") {
    throw new Error(`${mapPath} must set visibility: garden before quotes can be published`)
  }

  const parent = path.dirname(outputRoot)
  const stageRoot = path.join(parent, `.quotes-sync-stage-${process.pid}-${Date.now()}`)
  const backupRoot = path.join(parent, `.quotes-sync-backup-${process.pid}-${Date.now()}`)
  await rm(stageRoot, { recursive: true, force: true })
  await mkdir(stageRoot, { recursive: true })

  try {
    const indexData = {
      ...map.data,
      title: map.data.title ?? "Quotes I collected",
      publish: true,
      draft: false,
    }
    const indexText = await prettierFormat(renderMarkdown(indexData, map.body), {
      parser: "markdown",
    })
    assertPublicSafe(indexText, mapPath)
    await writeFile(path.join(stageRoot, "index.md"), indexText)

    const generated = ["index.md"]
    for (const sourcePath of await quoteFiles(path.join(quotesRoot, "Entries"))) {
      const parsed = parseMarkdown(await readFile(sourcePath, "utf8"), sourcePath)
      if (parsed.data.kind !== "quote") throw new Error(`${sourcePath} must set kind: quote`)
      if (parsed.data.publish !== true) continue
      if (typeof parsed.data.quote !== "string" || parsed.data.quote.trim() === "") {
        throw new Error(`${sourcePath} must contain a non-empty quote`)
      }
      const filename = path.basename(sourcePath, path.extname(sourcePath))
      const slug = safeSlug(parsed.data.slug ?? filename, sourcePath)
      const data = {
        ...parsed.data,
        title: parsed.data.title ?? parsed.data.quote,
        tags: [...new Set([...(Array.isArray(parsed.data.tags) ? parsed.data.tags : []), "quote"])],
        draft: false,
      }
      const body = parsed.body.trim() || `> ${parsed.data.quote}\n`
      const text = await prettierFormat(renderMarkdown(data, body), { parser: "markdown" })
      assertPublicSafe(text, sourcePath)
      await writeFile(path.join(stageRoot, `${slug}.md`), text)
      generated.push(`${slug}.md`)
    }

    await writeFile(
      path.join(stageRoot, MANIFEST),
      `${JSON.stringify({ version: 1, generatedAt: new Date().toISOString(), generated }, null, 2)}\n`,
    )

    if (dryRun) return { files: generated.length, generated }
    await mkdir(parent, { recursive: true })
    if (existsSync(outputRoot)) await rename(outputRoot, backupRoot)
    try {
      await rename(stageRoot, outputRoot)
      await rm(backupRoot, { recursive: true, force: true })
    } catch (error) {
      if (existsSync(backupRoot) && !existsSync(outputRoot)) await rename(backupRoot, outputRoot)
      throw error
    }
    return { files: generated.length, generated }
  } finally {
    await rm(stageRoot, { recursive: true, force: true })
    await rm(backupRoot, { recursive: true, force: true })
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
      "Usage: export-quotes --vault /path/to/vault --output /path/to/content/quotes [--dry-run]",
    )
  }
  return args
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : ""
if (import.meta.url === invokedPath) {
  exportQuotes(cliArgs(process.argv.slice(2)))
    .then((result) => console.log(`Quote export ready: ${result.files} files.`))
    .catch((error) => {
      console.error(error instanceof Error ? error.message : error)
      process.exitCode = 1
    })
}
