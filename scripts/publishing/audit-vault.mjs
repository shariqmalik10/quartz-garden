import { existsSync } from "node:fs"
import { readdir, stat } from "node:fs/promises"
import path from "node:path"

import {
  CONTRACT_VERSION,
  contractError,
  markdownFiles,
  normalizedSlug,
  readMarkdownDocument,
  safeRelativePath,
  safeSlug,
  validateDocument,
} from "./contracts.mjs"

function relative(vaultRoot, sourcePath) {
  return path.relative(vaultRoot, sourcePath).split(path.sep).join("/")
}

function record(collection, sourcePath, status, reason, target) {
  return { collection, path: sourcePath, status, reason, ...(target ? { target } : {}) }
}

function duplicateRecords(records, collection, keyName, entries) {
  const groups = new Map()
  for (const entry of entries) {
    const group = groups.get(entry.key) ?? []
    group.push(entry)
    groups.set(entry.key, group)
  }
  for (const [key, group] of groups) {
    if (group.length < 2) continue
    for (const entry of group) {
      const existing = records.find(
        (item) => item.collection === collection && item.path === entry.path,
      )
      if (existing) {
        existing.status = "blocked"
        existing.reason = `duplicate ${keyName} ${key}; also used by ${group
          .filter((item) => item.path !== entry.path)
          .map((item) => item.path)
          .join(", ")}`
      }
    }
  }
}

async function auditGarden(vaultRoot) {
  const collection = "garden"
  const records = []
  const identities = []
  const areasRoot = path.join(vaultRoot, "Areas")
  if (!existsSync(areasRoot)) {
    return [record(collection, "Areas", "blocked", "vault is missing Areas/")]
  }

  for (const entry of (await readdir(areasRoot, { withFileTypes: true })).filter((item) =>
    item.isDirectory(),
  )) {
    const mapPath = path.join(areasRoot, entry.name, `${entry.name}.md`)
    const mapRelative = relative(vaultRoot, mapPath)
    if (!existsSync(mapPath)) {
      records.push(record(collection, mapRelative, "skipped", "area has no map note"))
      continue
    }
    let area
    try {
      area = await readMarkdownDocument(mapPath)
      validateDocument("area", area.data, mapRelative)
    } catch (error) {
      records.push({ ...contractError(error, collection, mapRelative), status: "blocked" })
      continue
    }

    const captures = await markdownFiles(path.join(areasRoot, entry.name, "Captures"))
    if (area.data.visibility === "private") {
      records.push(record(collection, mapRelative, "skipped", "area visibility is private"))
      for (const capturePath of captures) {
        records.push(
          record(collection, relative(vaultRoot, capturePath), "skipped", "parent area is private"),
        )
      }
      continue
    }

    const siteSlug = safeRelativePath(area.data.site_slug, mapRelative, "area", "site_slug")
    records.push(
      record(collection, mapRelative, "included", "public area map", `${siteSlug}/index.md`),
    )
    identities.push({ key: `area:${siteSlug}`, path: mapRelative })

    for (const capturePath of captures) {
      const captureRelative = relative(vaultRoot, capturePath)
      try {
        const capture = await readMarkdownDocument(capturePath)
        validateDocument("capture", capture.data, captureRelative)
        const id = safeSlug(capture.data.id, captureRelative, "capture")
        const target = `${siteSlug}/${id}.md`
        records.push(
          record(collection, captureRelative, "included", "capture is in a public area", target),
        )
        identities.push({ key: `capture:${target}`, path: captureRelative })
      } catch (error) {
        records.push({ ...contractError(error, collection, captureRelative), status: "blocked" })
      }
    }
  }

  duplicateRecords(records, collection, "public target", identities)
  return records
}

async function auditQuotes(vaultRoot) {
  const collection = "quotes"
  const records = []
  const quotesRoot = path.join(vaultRoot, "Quotes")
  const mapPath = path.join(quotesRoot, "Quotes.md")
  const mapRelative = relative(vaultRoot, mapPath)
  if (!existsSync(mapPath))
    return [record(collection, mapRelative, "blocked", "quote map is missing")]

  let map
  try {
    map = await readMarkdownDocument(mapPath)
    validateDocument("quote-collection", map.data, mapRelative)
  } catch (error) {
    return [{ ...contractError(error, collection, mapRelative), status: "blocked" }]
  }
  if (map.data.visibility !== "garden") {
    return [record(collection, mapRelative, "skipped", "quote collection visibility is private")]
  }
  records.push(record(collection, mapRelative, "included", "public quote collection", "index.md"))

  const identities = []
  for (const sourcePath of await markdownFiles(path.join(quotesRoot, "Entries"))) {
    const sourceRelative = relative(vaultRoot, sourcePath)
    let parsed
    try {
      parsed = await readMarkdownDocument(sourcePath)
      if (parsed.data.kind !== "quote") {
        validateDocument("quote", parsed.data, sourceRelative)
      }
      if (parsed.data.publish !== true) {
        records.push(record(collection, sourceRelative, "skipped", "publish is not true"))
        continue
      }
      validateDocument("quote", parsed.data, sourceRelative)
      const filename = path.basename(sourcePath, path.extname(sourcePath))
      const slug = safeSlug(parsed.data.slug ?? filename, sourceRelative, "quote")
      const target = `${slug}.md`
      records.push(
        record(collection, sourceRelative, "included", "quote is marked for publication", target),
      )
      identities.push({ key: target, path: sourceRelative })
    } catch (error) {
      records.push({ ...contractError(error, collection, sourceRelative), status: "blocked" })
    }
  }
  duplicateRecords(records, collection, "quote slug", identities)
  return records
}

async function auditWriting(vaultRoot) {
  const collection = "writing"
  const records = []
  const identities = []
  const writingRoot = path.join(vaultRoot, "Writing")
  if (!existsSync(writingRoot) || !(await stat(writingRoot)).isDirectory()) {
    return [record(collection, "Writing", "blocked", "vault is missing Writing/")]
  }

  for (const sourcePath of await markdownFiles(writingRoot)) {
    const sourceRelative = relative(vaultRoot, sourcePath)
    try {
      const parsed = await readMarkdownDocument(sourcePath, { required: false })
      if (!parsed || parsed.data.kind !== "writing") {
        records.push(record(collection, sourceRelative, "skipped", "not a managed writing note"))
        continue
      }
      if (parsed.data.visibility !== "public" || parsed.data.draft !== false) {
        records.push(
          record(collection, sourceRelative, "skipped", "writing is private or still a draft"),
        )
        continue
      }
      validateDocument("writing", parsed.data, sourceRelative)
      const filename = path.basename(sourcePath, path.extname(sourcePath))
      const slug = normalizedSlug(parsed.data.slug || filename, sourceRelative, "writing")
      if (slug === "index") throw new Error(`${sourceRelative} cannot use the reserved index slug`)
      const target = `${slug}.md`
      records.push(
        record(collection, sourceRelative, "included", "writing is public and not a draft", target),
      )
      identities.push({ key: target, path: sourceRelative })
    } catch (error) {
      records.push({ ...contractError(error, collection, sourceRelative), status: "blocked" })
    }
  }
  duplicateRecords(records, collection, "writing slug", identities)
  return records
}

export async function auditVault(vaultRoot) {
  const resolvedVault = path.resolve(vaultRoot)
  const records = [
    ...(await auditGarden(resolvedVault)),
    ...(await auditQuotes(resolvedVault)),
    ...(await auditWriting(resolvedVault)),
  ]
  const summary = { included: 0, skipped: 0, blocked: 0 }
  for (const item of records) summary[item.status] += 1
  return {
    contractVersion: CONTRACT_VERSION,
    vaultRoot: resolvedVault,
    ok: summary.blocked === 0,
    summary,
    records,
  }
}
