#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises"
import path from "node:path"
import { pathToFileURL } from "node:url"

import YAML from "yaml"

import { CONTRACT_VERSION, markdownFiles, parseMarkdownDocument } from "./publishing/contracts.mjs"

export function migrateFrontmatter(data) {
  const next = { ...data }
  const changes = []

  if (next.kind === "writing" && typeof next.published === "boolean") {
    if (next.visibility === undefined) {
      next.visibility = next.published ? "public" : "private"
      changes.push(`set visibility from legacy published: ${next.published}`)
    }
    if (next.draft === undefined) {
      next.draft = !next.published
      changes.push(`set draft from legacy published: ${next.published}`)
    }
    delete next.published
    changes.push("remove legacy published field")
  }

  if (next.kind === "quote" && next.captured_at === undefined && next.date !== undefined) {
    next.captured_at = next.date
    changes.push("copy date to captured_at")
  }

  if (["writing", "quote", "capture", "area", "quote-collection"].includes(next.kind)) {
    if (next.contract_version === undefined) {
      next.contract_version = CONTRACT_VERSION
      changes.push(`set contract_version to ${CONTRACT_VERSION}`)
    }
  }

  return { data: next, changes }
}

function renderMarkdown(data, body) {
  return `---\n${YAML.stringify(data).trimEnd()}\n---\n\n${body.replace(/^\s+/, "")}`
}

function renderMigration(originalText, parsed, migrated) {
  if (
    migrated.changes.length === 1 &&
    migrated.changes[0] === `set contract_version to ${CONTRACT_VERSION}`
  ) {
    return originalText.replace(/^---\r?\n/, `---\ncontract_version: ${CONTRACT_VERSION}\n`)
  }
  return renderMarkdown(migrated.data, parsed.body)
}

export async function migrationReport({ vaultRoot, write = false }) {
  const resolvedVault = path.resolve(vaultRoot)
  const roots = ["Areas", "Quotes", "Writing"]
  const files = (
    await Promise.all(roots.map((root) => markdownFiles(path.join(resolvedVault, root))))
  ).flat()
  const records = []

  for (const sourcePath of files) {
    const text = await readFile(sourcePath, "utf8")
    const parsed = parseMarkdownDocument(text, sourcePath, { required: false })
    if (!parsed) continue
    const migrated = migrateFrontmatter(parsed.data)
    if (migrated.changes.length === 0) continue
    if (write) await writeFile(sourcePath, renderMigration(text, parsed, migrated))
    records.push({
      path: path.relative(resolvedVault, sourcePath).split(path.sep).join("/"),
      changes: migrated.changes,
      status: write ? "migrated" : "would-migrate",
    })
  }

  return { contractVersion: CONTRACT_VERSION, write, files: records.length, records }
}

function cliArgs(argv) {
  const args = { write: false, json: false }
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index]
    if (item === "--vault") args.vaultRoot = argv[++index]
    else if (item === "--write") args.write = true
    else if (item === "--json") args.json = true
    else throw new Error(`Unknown argument: ${item}`)
  }
  if (!args.vaultRoot)
    throw new Error("Usage: migrate-content --vault /path/to/vault [--write] [--json]")
  return args
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : ""
if (import.meta.url === invokedPath) {
  try {
    const args = cliArgs(process.argv.slice(2))
    const report = await migrationReport(args)
    if (args.json) console.log(JSON.stringify(report, null, 2))
    else {
      console.log(`${report.write ? "Migrated" : "Migration preview"}: ${report.files} files.`)
      for (const record of report.records) {
        console.log(`${record.status.toUpperCase()} ${record.path} — ${record.changes.join("; ")}`)
      }
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : error)
    process.exitCode = 1
  }
}
