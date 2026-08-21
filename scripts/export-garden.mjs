#!/usr/bin/env node

import { createHash } from "node:crypto"
import { existsSync } from "node:fs"
import { cp, mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises"
import path from "node:path"
import { pathToFileURL } from "node:url"
import { format as prettierFormat } from "prettier"
import YAML from "yaml"

const MANIFEST = ".garden-sync-manifest.json"
const MARKDOWN_EXTENSIONS = new Set([".md", ".markdown"])

function inside(parent, child) {
  const relative = path.relative(parent, child)
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative))
}

function safeRelative(value, label) {
  if (
    typeof value !== "string" ||
    value.trim() === "" ||
    path.isAbsolute(value) ||
    value.split(/[\\/]/).some((part) => part === ".." || part === "")
  ) {
    throw new Error(`${label} must be a safe relative path: ${String(value)}`)
  }
  return value
    .split("\\")
    .join("/")
    .replace(/^\/+|\/+$/g, "")
}

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

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
}

function externalLinkList(captures) {
  const items = captures
    .filter(({ data }) => {
      const tags = Array.isArray(data.tags) ? data.tags : []
      return (
        data.publish !== false &&
        !tags.includes("system-test") &&
        typeof data.source === "string" &&
        /^https?:\/\//i.test(data.source) &&
        typeof data.title === "string" &&
        data.title.trim() !== ""
      )
    })
    .sort((a, b) => {
      const aTime = Date.parse(a.data.captured_at ?? "") || 0
      const bTime = Date.parse(b.data.captured_at ?? "") || 0
      return bTime - aTime
    })
    .map(
      ({ data }) =>
        `  <li><a href="${escapeHtml(data.source)}">${escapeHtml(data.title.trim())}</a></li>`,
    )

  if (items.length === 0) return ""
  return `<ul class="garden-link-list">\n${items.join("\n")}\n</ul>`
}

function sensitiveFinding(text) {
  const checks = [
    ["email address", /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i],
    ["LinkedIn reference", /\blinkedin\.com\b/i],
    [
      "phone number",
      /(?:\+\d[\d ().-]{7,}\d|\b(?:phone|mobile|tel(?:ephone)?)\s*[:=-]?\s*\d[\d ().-]{6,}\d)/i,
    ],
    ["resume reference", /\b(?:resume|résumé)\b/i],
    [
      "credential-like text",
      /\b(?:password|client[_ -]?secret|api[_ -]?key|private[_ -]?key|aws_access_key_id)\b\s*[:=]/i,
    ],
    ["token-like value", /\b(?:github_pat_|gh[pousr]_|xox[baprs]-)[A-Za-z0-9_-]{8,}/i],
    ["private key", /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
  ]
  return checks.find(([, pattern]) => pattern.test(text))?.[0]
}

function redactPrivateWikilinks(text, privateAreas) {
  return text.replace(/!?\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]/g, (match, rawTarget) => {
    const target = rawTarget.trim().replace(/\\/g, "/")
    const lower = target.toLowerCase()
    const isPrivateRoot = lower === "private" || lower.startsWith("private/")
    const isPrivateArea = [...privateAreas].some((area) => {
      const areaLower = area.toLowerCase()
      return (
        lower === areaLower ||
        lower.startsWith(`${areaLower}/`) ||
        lower === `areas/${areaLower}` ||
        lower.startsWith(`areas/${areaLower}/`)
      )
    })
    return isPrivateRoot || isPrivateArea ? "[private reference omitted]" : match
  })
}

async function markdownFiles(directory) {
  if (!existsSync(directory)) return []
  const entries = await readdir(directory, { withFileTypes: true })
  return entries
    .filter(
      (entry) => entry.isFile() && MARKDOWN_EXTENSIONS.has(path.extname(entry.name).toLowerCase()),
    )
    .map((entry) => path.join(directory, entry.name))
    .sort()
}

async function readManifest(outputRoot) {
  const manifestPath = path.join(outputRoot, MANIFEST)
  if (!existsSync(manifestPath)) return { generated: [] }
  const parsed = JSON.parse(await readFile(manifestPath, "utf8"))
  if (!Array.isArray(parsed.generated)) throw new Error(`Invalid ${MANIFEST}`)
  return {
    generated: parsed.generated.map((item) => safeRelative(item, "manifest path")),
  }
}

async function removeEmptyParents(root, filePath) {
  let current = path.dirname(filePath)
  while (current !== root && inside(root, current)) {
    try {
      const entries = await readdir(current)
      if (entries.length > 0) return
      await rm(current, { recursive: false })
      current = path.dirname(current)
    } catch {
      return
    }
  }
}

async function copyOwnedAttachments({ vaultRoot, stageRoot, outputArea, captureId, attachments }) {
  const rewritten = new Map()
  for (const raw of attachments) {
    if (typeof raw !== "string") continue
    const match = raw.match(/^!?\[\[([^\]|]+)(?:\|[^\]]+)?\]\]$/)
    if (!match) throw new Error(`Attachment must be an Obsidian wikilink: ${raw}`)
    const sourceRelative = safeRelative(match[1], "attachment path")
    if (!sourceRelative.startsWith("Attachments/Captures/")) {
      throw new Error(`Attachment is outside Attachments/Captures: ${sourceRelative}`)
    }
    const source = path.resolve(vaultRoot, sourceRelative)
    if (!inside(vaultRoot, source) || !existsSync(source) || !(await stat(source)).isFile()) {
      throw new Error(`Owned attachment not found: ${sourceRelative}`)
    }
    const targetRelative = path.posix.join(
      outputArea,
      "assets",
      captureId,
      path.basename(sourceRelative),
    )
    const target = path.resolve(stageRoot, targetRelative)
    if (!inside(stageRoot, target))
      throw new Error(`Attachment target escaped output: ${targetRelative}`)
    await mkdir(path.dirname(target), { recursive: true })
    await cp(source, target)
    rewritten.set(match[1], path.posix.join("assets", captureId, path.basename(sourceRelative)))
  }
  return rewritten
}

function rewriteAttachmentLinks(text, rewritten) {
  for (const [source, target] of rewritten) {
    text = text.replaceAll(`[[${source}]]`, `[[${target}]]`)
    text = text.replaceAll(`![[${source}]]`, `![[${target}]]`)
  }
  return text
}

function assertPublicSafe(text, sourcePath) {
  const finding = sensitiveFinding(text)
  if (finding) throw new Error(`${sourcePath} contains blocked ${finding}`)
  if (/!?\[\[(?:Private(?:\/|\]|#)|Areas\/Private(?:\/|\]|#))/i.test(text)) {
    throw new Error(`${sourcePath} still contains a private wikilink`)
  }
}

export async function exportGarden({ vaultRoot, outputRoot, dryRun = false }) {
  vaultRoot = path.resolve(vaultRoot)
  outputRoot = path.resolve(outputRoot)
  const areasRoot = path.join(vaultRoot, "Areas")
  if (!existsSync(vaultRoot) || !(await stat(vaultRoot)).isDirectory()) {
    throw new Error(`Vault not found: ${vaultRoot}`)
  }
  if (!existsSync(areasRoot)) throw new Error(`Vault is missing Areas/: ${vaultRoot}`)

  const areaEntries = (await readdir(areasRoot, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
    .sort((a, b) => a.name.localeCompare(b.name))

  const areas = []
  for (const entry of areaEntries) {
    const areaMapPath = path.join(areasRoot, entry.name, `${entry.name}.md`)
    if (!existsSync(areaMapPath)) continue
    const parsed = parseMarkdown(await readFile(areaMapPath, "utf8"), areaMapPath)
    if (parsed.data.kind !== "area") throw new Error(`${areaMapPath} must set kind: area`)
    const visibility = parsed.data.visibility
    if (visibility !== "garden" && visibility !== "private") {
      throw new Error(`${areaMapPath} visibility must be garden or private`)
    }
    areas.push({
      name: entry.name,
      root: path.dirname(areaMapPath),
      mapPath: areaMapPath,
      ...parsed,
    })
  }

  const privateAreas = new Set(
    areas.filter((area) => area.data.visibility === "private").map((area) => area.name),
  )
  const publicAreas = areas.filter((area) => area.data.visibility === "garden")
  const oldManifest = await readManifest(outputRoot)
  const parent = path.dirname(outputRoot)
  const stageRoot = path.join(parent, `.garden-sync-stage-${process.pid}-${Date.now()}`)
  const backupRoot = path.join(parent, `.garden-sync-backup-${process.pid}-${Date.now()}`)
  await rm(stageRoot, { recursive: true, force: true })
  await mkdir(stageRoot, { recursive: true })

  try {
    if (existsSync(outputRoot)) await cp(outputRoot, stageRoot, { recursive: true })
    for (const relative of oldManifest.generated) {
      const target = path.resolve(stageRoot, relative)
      if (!inside(stageRoot, target)) throw new Error(`Manifest path escaped output: ${relative}`)
      await rm(target, { recursive: true, force: true })
      await removeEmptyParents(stageRoot, target)
    }

    const generated = []
    const sources = []
    for (const area of publicAreas) {
      const outputArea = safeRelative(area.data.site_slug, `${area.mapPath} site_slug`)
      const mediaPolicy = area.data.media_policy ?? "reference"
      if (mediaPolicy !== "reference" && mediaPolicy !== "owned") {
        throw new Error(`${area.mapPath} media_policy must be reference or owned`)
      }

      const captures = []
      for (const capturePath of await markdownFiles(path.join(area.root, "Captures"))) {
        const capture = parseMarkdown(await readFile(capturePath, "utf8"), capturePath)
        if (capture.data.kind !== "capture")
          throw new Error(`${capturePath} must set kind: capture`)
        captures.push({ path: capturePath, ...capture })
      }

      const externalListing = area.data.listing_style === "external-links"
      const publicMapData = {
        ...area.data,
        title: area.data.title ?? area.name,
        permalink: `/${outputArea}`,
        publish: true,
        draft: false,
        ...(externalListing
          ? { cssclasses: [...new Set([...(area.data.cssclasses ?? []), "external-link-index"])] }
          : {}),
      }
      let publicMapBody = redactPrivateWikilinks(area.body, privateAreas)
      if (externalListing) {
        const listing = externalLinkList(captures)
        if (listing) publicMapBody = `${publicMapBody.trimEnd()}\n\n${listing}\n`
      }
      const mapText = await prettierFormat(renderMarkdown(publicMapData, publicMapBody), {
        parser: "markdown",
      })
      assertPublicSafe(mapText, area.mapPath)
      const mapRelative = path.posix.join(outputArea, "index.md")
      const mapTarget = path.resolve(stageRoot, mapRelative)
      if (!inside(stageRoot, mapTarget)) throw new Error(`Area output escaped root: ${mapRelative}`)
      await mkdir(path.dirname(mapTarget), { recursive: true })
      await writeFile(mapTarget, mapText)
      generated.push(mapRelative)
      sources.push({
        path: path.relative(vaultRoot, area.mapPath),
        sha256: createHash("sha256").update(mapText).digest("hex"),
      })

      for (const capture of captures) {
        const capturePath = capture.path
        const captureId = safeRelative(
          String(capture.data.id ?? path.basename(capturePath, path.extname(capturePath))),
          `${capturePath} id`,
        )
        if (captureId.includes("/")) throw new Error(`${capturePath} id must not contain a slash`)
        let data = {
          ...capture.data,
          visibility: "garden",
          permalink: `/${outputArea}/${captureId}`,
          publish: true,
          draft: false,
        }
        let body = redactPrivateWikilinks(capture.body, privateAreas)

        const attachments = Array.isArray(capture.data.attachments) ? capture.data.attachments : []
        if (mediaPolicy === "owned") {
          const rewritten = await copyOwnedAttachments({
            vaultRoot,
            stageRoot,
            outputArea,
            captureId,
            attachments,
          })
          data = {
            ...data,
            attachments: attachments.map((item) => {
              if (typeof item !== "string") return item
              const match = item.match(/^!?\[\[([^\]|]+)(?:\|[^\]]+)?\]\]$/)
              return match && rewritten.has(match[1]) ? `[[${rewritten.get(match[1])}]]` : item
            }),
          }
          body = rewriteAttachmentLinks(body, rewritten)
          for (const target of rewritten.values())
            generated.push(path.posix.join(outputArea, target))
        } else {
          data = { ...data, attachments: [] }
          body = body.replace(/!?\[\[Attachments\/Captures\/[^\]]+\]\]/g, "[source media omitted]")
        }

        const captureText = await prettierFormat(renderMarkdown(data, body), { parser: "markdown" })
        assertPublicSafe(captureText, capturePath)
        const captureRelative = path.posix.join(outputArea, `${captureId}.md`)
        const captureTarget = path.resolve(stageRoot, captureRelative)
        if (!inside(stageRoot, captureTarget))
          throw new Error(`Capture output escaped root: ${captureRelative}`)
        await mkdir(path.dirname(captureTarget), { recursive: true })
        await writeFile(captureTarget, captureText)
        generated.push(captureRelative)
        sources.push({
          path: path.relative(vaultRoot, capturePath),
          sha256: createHash("sha256").update(captureText).digest("hex"),
        })
      }
    }

    const uniqueGenerated = [...new Set(generated)].sort()
    const manifest = {
      version: 1,
      generatedAt: new Date().toISOString(),
      generated: uniqueGenerated,
      sources,
    }
    await writeFile(path.join(stageRoot, MANIFEST), `${JSON.stringify(manifest, null, 2)}\n`)

    if (dryRun) {
      return {
        areas: publicAreas.length,
        files: uniqueGenerated.length,
        generated: uniqueGenerated,
      }
    }

    await mkdir(parent, { recursive: true })
    if (existsSync(outputRoot)) await rename(outputRoot, backupRoot)
    try {
      await rename(stageRoot, outputRoot)
      await rm(backupRoot, { recursive: true, force: true })
    } catch (error) {
      if (existsSync(backupRoot) && !existsSync(outputRoot)) await rename(backupRoot, outputRoot)
      throw error
    }
    return { areas: publicAreas.length, files: uniqueGenerated.length, generated: uniqueGenerated }
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
      "Usage: export-garden --vault /path/to/vault --output /path/to/content/garden-sync [--dry-run]",
    )
  }
  return args
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : ""
if (import.meta.url === invokedPath) {
  exportGarden(cliArgs(process.argv.slice(2)))
    .then((result) =>
      console.log(`Garden export ready: ${result.areas} areas, ${result.files} files.`),
    )
    .catch((error) => {
      console.error(error instanceof Error ? error.message : error)
      process.exitCode = 1
    })
}
