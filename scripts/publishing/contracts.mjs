import { existsSync } from "node:fs"
import { readFile, readdir } from "node:fs/promises"
import path from "node:path"

import YAML from "yaml"

export const CONTRACT_VERSION = 1

export const CONTENT_CONTRACTS = Object.freeze({
  area: {
    version: CONTRACT_VERSION,
    required: ["kind", "visibility", "site_slug"],
    enums: {
      kind: ["area"],
      visibility: ["garden", "private"],
      media_policy: ["reference", "owned"],
    },
    patterns: { site_slug: "safe-path" },
  },
  capture: {
    version: CONTRACT_VERSION,
    required: ["id", "kind", "title"],
    enums: { kind: ["capture"] },
    patterns: { id: "slug", source: "http-url" },
  },
  "quote-collection": {
    version: CONTRACT_VERSION,
    required: ["kind", "visibility"],
    enums: { kind: ["quote-collection"], visibility: ["garden", "private"] },
  },
  quote: {
    version: CONTRACT_VERSION,
    required: ["kind", "quote", "publish"],
    enums: { kind: ["quote"], publish: [true, false] },
    patterns: { slug: "slug", sourceUrl: "http-url" },
  },
  writing: {
    version: CONTRACT_VERSION,
    required: ["kind", "title", "date", "visibility", "draft"],
    enums: {
      kind: ["writing"],
      visibility: ["public", "private"],
      draft: [true, false],
    },
    patterns: { slug: "slug" },
  },
})

export class ContentContractError extends Error {
  constructor({ code, collection, sourcePath, message, details = [] }) {
    super(`${sourcePath} ${message}`)
    this.name = "ContentContractError"
    this.code = code
    this.collection = collection
    this.sourcePath = sourcePath
    this.details = details
  }

  toJSON() {
    return {
      name: this.name,
      code: this.code,
      collection: this.collection,
      path: this.sourcePath,
      message: this.message,
      details: this.details,
    }
  }
}

function fail(collection, sourcePath, code, message, details = []) {
  throw new ContentContractError({ code, collection, sourcePath, message, details })
}

export function parseMarkdownDocument(text, sourcePath, { required = true } = {}) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)([\s\S]*)$/)
  if (!match) {
    if (!required) return null
    fail("unknown", sourcePath, "frontmatter_missing", "must begin with YAML frontmatter")
  }
  let data
  try {
    data = YAML.parse(match[1]) ?? {}
  } catch (error) {
    fail(
      "unknown",
      sourcePath,
      "frontmatter_invalid",
      `contains invalid YAML frontmatter: ${error instanceof Error ? error.message : error}`,
    )
  }
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    fail("unknown", sourcePath, "frontmatter_invalid", "frontmatter must be a mapping")
  }
  return { data, body: match[2] }
}

export function safeSlug(value, sourcePath, collection) {
  const slug = String(value ?? "").trim()
  if (!/^[a-z0-9][a-z0-9-]*$/i.test(slug)) {
    fail(
      collection,
      sourcePath,
      "slug_invalid",
      "slug must contain only letters, numbers, and hyphens",
    )
  }
  return slug.toLowerCase()
}

export function normalizedSlug(value, sourcePath, collection) {
  const slug = String(value ?? "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
  if (!slug) fail(collection, sourcePath, "slug_invalid", "needs a slug with letters or numbers")
  return slug
}

export function safeRelativePath(value, sourcePath, collection, field = "path") {
  if (
    typeof value !== "string" ||
    value.trim() === "" ||
    path.isAbsolute(value) ||
    value.split(/[\\/]/).some((part) => part === ".." || part === "")
  ) {
    fail(collection, sourcePath, "path_unsafe", `${field} must be a safe relative path`)
  }
  return value
    .split("\\")
    .join("/")
    .replace(/^\/+|\/+$/g, "")
}

function hasValue(value) {
  return value !== undefined && value !== null && (typeof value !== "string" || value.trim() !== "")
}

export function validateDocument(collection, data, sourcePath) {
  const contract = CONTENT_CONTRACTS[collection]
  if (!contract)
    fail(collection, sourcePath, "contract_unknown", `uses unknown contract ${collection}`)

  const details = []
  if (data.contract_version !== undefined && data.contract_version !== CONTRACT_VERSION) {
    details.push({
      field: "contract_version",
      code: "version",
      message: `must be ${CONTRACT_VERSION}`,
    })
  }
  for (const field of contract.required) {
    if (!hasValue(data[field])) details.push({ field, code: "required", message: "is required" })
  }
  for (const [field, allowed] of Object.entries(contract.enums ?? {})) {
    if (data[field] !== undefined && !allowed.includes(data[field])) {
      details.push({ field, code: "enum", message: `must be one of: ${allowed.join(", ")}` })
    }
  }
  for (const [field, rule] of Object.entries(contract.patterns ?? {})) {
    if (!hasValue(data[field])) continue
    const value = String(data[field])
    if (rule === "slug" && !/^[a-z0-9][a-z0-9-]*$/i.test(value)) {
      details.push({
        field,
        code: "slug",
        message: "must contain only letters, numbers, and hyphens",
      })
    } else if (rule === "safe-path") {
      try {
        safeRelativePath(value, sourcePath, collection, field)
      } catch (error) {
        details.push({ field, code: "safe-path", message: "must be a safe relative path" })
      }
    } else if (rule === "http-url" && !/^https?:\/\/[^\s]+$/i.test(value)) {
      details.push({ field, code: "http-url", message: "must be an HTTP or HTTPS URL" })
    }
  }

  if (details.length > 0) {
    const summary = details.map(({ field, message }) => `${field} ${message}`).join("; ")
    fail(
      collection,
      sourcePath,
      "schema_invalid",
      `does not match ${collection} v${CONTRACT_VERSION}: ${summary}`,
      details,
    )
  }
  return data
}

const SAFETY_CHECKS = {
  common: [
    ["private wikilink", /!?\[\[(?:Private(?:\/|\]|#)|Areas\/Private(?:\/|\]|#))/i],
    [
      "credential-like text",
      /\b(?:password|client[_ -]?secret|api[_ -]?key|private[_ -]?key|aws_access_key_id)\b\s*[:=]/i,
    ],
    ["private key", /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
  ],
  contact: [
    ["email address", /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i],
    ["LinkedIn reference", /\blinkedin\.com\b/i],
    ["resume reference", /\b(?:resume|résumé)\b/i],
  ],
}

export function assertPublicSafe(text, sourcePath, collection, { blockContact = false } = {}) {
  const checks = blockContact
    ? [...SAFETY_CHECKS.common, ...SAFETY_CHECKS.contact]
    : SAFETY_CHECKS.common
  const finding = checks.find(([, pattern]) => pattern.test(text))
  if (finding) fail(collection, sourcePath, "public_safety", `contains blocked ${finding[0]}`)
}

export async function markdownFiles(directory) {
  if (!existsSync(directory)) return []
  const files = []
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.name.startsWith(".") || entry.isSymbolicLink()) continue
    const entryPath = path.join(directory, entry.name)
    if (entry.isDirectory()) files.push(...(await markdownFiles(entryPath)))
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(".md")) files.push(entryPath)
  }
  return files.sort()
}

export async function readMarkdownDocument(sourcePath, options) {
  return parseMarkdownDocument(await readFile(sourcePath, "utf8"), sourcePath, options)
}

export function contractError(error, collection, sourcePath) {
  if (error instanceof ContentContractError) return error.toJSON()
  return {
    name: "Error",
    code: "validation_failed",
    collection,
    path: sourcePath,
    message: error instanceof Error ? error.message : String(error),
    details: [],
  }
}
