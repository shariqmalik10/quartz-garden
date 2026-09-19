#!/usr/bin/env node

import path from "node:path"
import { pathToFileURL } from "node:url"

import { exportGarden } from "./export-garden.mjs"
import { exportQuotes } from "./export-quotes.mjs"
import { exportWriting } from "./export-writing.mjs"

export async function checkPublishing({ vaultRoot, siteRoot }) {
  const resolvedVault = path.resolve(vaultRoot)
  const resolvedSite = path.resolve(siteRoot)
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
    try {
      const result = await collection.run()
      results.push({
        key: collection.key,
        label: collection.label,
        status: "ready",
        ...result,
      })
    } catch (error) {
      results.push({
        key: collection.key,
        label: collection.label,
        status: "blocked",
        error: error instanceof Error ? error.message : String(error),
      })
    }
  }

  return {
    ok: results.every((result) => result.status === "ready"),
    vaultRoot: resolvedVault,
    siteRoot: resolvedSite,
    collections: results,
  }
}

export function formatPublishingReport(report) {
  const lines = [report.ok ? "Publication check passed." : "Publication check is blocked."]
  for (const result of report.collections) {
    if (result.status === "blocked") {
      lines.push(`✗ ${result.label}: ${result.error}`)
      continue
    }
    const areaSummary = typeof result.areas === "number" ? `${result.areas} areas, ` : ""
    lines.push(`✓ ${result.label}: ${areaSummary}${result.files} files ready`)
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
