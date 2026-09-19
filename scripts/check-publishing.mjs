#!/usr/bin/env node

import path from "node:path"
import { pathToFileURL } from "node:url"

import { exportGarden } from "./export-garden.mjs"
import { exportQuotes } from "./export-quotes.mjs"
import { exportWriting } from "./export-writing.mjs"
import { auditVault } from "./publishing/audit-vault.mjs"

export async function checkPublishing({ vaultRoot, siteRoot }) {
  const resolvedVault = path.resolve(vaultRoot)
  const resolvedSite = path.resolve(siteRoot)
  const audit = await auditVault(resolvedVault)
  const collections = [
    {
      key: "garden",
      label: "Garden captures",
      run: () =>
        exportGarden({
          vaultRoot: resolvedVault,
          outputRoot: path.join(resolvedSite, "content", "garden-sync"),
          dryRun: true,
        }),
    },
    {
      key: "quotes",
      label: "Quotes",
      run: () =>
        exportQuotes({
          vaultRoot: resolvedVault,
          outputRoot: path.join(resolvedSite, "content", "quotes"),
          dryRun: true,
        }),
    },
    {
      key: "writing",
      label: "Writing",
      run: () =>
        exportWriting({
          vaultRoot: resolvedVault,
          outputRoot: path.join(resolvedSite, "content", "notes"),
          dryRun: true,
        }),
    },
  ]

  const results = []
  for (const collection of collections) {
    const records = audit.records.filter((record) => record.collection === collection.key)
    const auditBlocked = records.filter((record) => record.status === "blocked")
    try {
      const result = await collection.run()
      results.push({
        key: collection.key,
        label: collection.label,
        status: auditBlocked.length === 0 ? "ready" : "blocked",
        records,
        ...result,
      })
    } catch (error) {
      results.push({
        key: collection.key,
        label: collection.label,
        status: "blocked",
        records,
        error: error instanceof Error ? error.message : String(error),
      })
    }
  }

  return {
    ok: results.every((result) => result.status === "ready"),
    contractVersion: audit.contractVersion,
    summary: audit.summary,
    vaultRoot: resolvedVault,
    siteRoot: resolvedSite,
    collections: results,
  }
}

export function formatPublishingReport(report) {
  const lines = [
    report.ok ? "Publication check passed." : "Publication check is blocked.",
    `Content contract v${report.contractVersion}: ${report.summary.included} included, ${report.summary.skipped} skipped, ${report.summary.blocked} blocked.`,
  ]
  for (const result of report.collections) {
    const counts = { included: 0, skipped: 0, blocked: 0 }
    for (const record of result.records) counts[record.status] += 1
    const areaSummary = typeof result.areas === "number" ? `${result.areas} areas, ` : ""
    lines.push(
      `${result.status === "ready" ? "✓" : "✗"} ${result.label}: ${areaSummary}${result.files ?? 0} generated; ${counts.included} included, ${counts.skipped} skipped, ${counts.blocked} blocked`,
    )
    if (result.error) lines.push(`  BLOCKED exporter — ${result.error}`)
    for (const record of result.records) {
      const target = record.target ? ` → ${record.target}` : ""
      lines.push(
        `  ${record.status.toUpperCase()} ${record.path}${target} — ${record.reason ?? record.message}`,
      )
    }
  }
  return lines.join("\n")
}

function cliArgs(argv) {
  const args = { siteRoot: process.cwd(), json: false }
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index]
    if (item === "--vault") args.vaultRoot = argv[++index]
    else if (item === "--site") args.siteRoot = argv[++index]
    else if (item === "--json") args.json = true
    else throw new Error(`Unknown argument: ${item}`)
  }
  if (!args.vaultRoot) {
    throw new Error(
      "Usage: check-publishing --vault /path/to/vault [--site /path/to/quartz] [--json]",
    )
  }
  return args
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : ""
if (import.meta.url === invokedPath) {
  try {
    const args = cliArgs(process.argv.slice(2))
    const report = await checkPublishing(args)
    console.log(args.json ? JSON.stringify(report, null, 2) : formatPublishingReport(report))
    if (!report.ok) process.exitCode = 1
  } catch (error) {
    console.error(error instanceof Error ? error.message : error)
    process.exitCode = 1
  }
}
