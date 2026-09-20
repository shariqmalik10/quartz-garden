import YAML from "yaml"

import { attachmentPathFromWikilink } from "./attachments"
import type { CollectionKey, VaultItem } from "./types"

export type EditorFields = {
  collection: CollectionKey
  title: string
  slug: string
  body: string
  description: string
  date: string
  tags: string[]
  visibility: "public" | "private"
  draft: boolean
  quote: string
  author: string
  sourceName: string
  sourceUrl: string
  capturedAt: string
  publish: boolean
  area: string
  metadataStatus: "complete" | "partial" | "pending"
  attachments: string[]
}

export function parseEditorFields(value: unknown): EditorFields | null {
  if (!value || typeof value !== "object") return null
  const input = value as Record<string, unknown>
  const strings = [
    "title",
    "slug",
    "body",
    "description",
    "date",
    "quote",
    "author",
    "sourceName",
    "sourceUrl",
    "capturedAt",
    "area",
  ]
  if (strings.some((key) => typeof input[key] !== "string")) return null
  if (!["writing", "quotes", "links"].includes(String(input.collection))) return null
  if (!["public", "private"].includes(String(input.visibility))) return null
  if (!["complete", "partial", "pending"].includes(String(input.metadataStatus))) return null
  if (typeof input.draft !== "boolean" || typeof input.publish !== "boolean") return null
  if (!Array.isArray(input.tags) || input.tags.some((tag) => typeof tag !== "string")) return null
  if (
    input.attachments !== undefined &&
    (!Array.isArray(input.attachments) ||
      input.attachments.some((attachment) => typeof attachment !== "string"))
  )
    return null
  return {
    collection: input.collection as CollectionKey,
    title: input.title as string,
    slug: input.slug as string,
    body: input.body as string,
    description: input.description as string,
    date: input.date as string,
    tags: input.tags as string[],
    visibility: input.visibility as EditorFields["visibility"],
    draft: input.draft,
    quote: input.quote as string,
    author: input.author as string,
    sourceName: input.sourceName as string,
    sourceUrl: input.sourceUrl as string,
    capturedAt: input.capturedAt as string,
    publish: input.publish,
    area: input.area as string,
    metadataStatus: input.metadataStatus as EditorFields["metadataStatus"],
    attachments: (input.attachments as string[] | undefined) || [],
  }
}

export type ContentValidation = { field: keyof EditorFields | "path"; message: string }

export function slugify(value: string) {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}

function cleanTags(tags: string[]) {
  return [...new Set(tags.map((tag) => tag.trim().replace(/^#/, "")).filter(Boolean))]
}

function httpUrl(value: string) {
  if (!value) return true
  try {
    const url = new URL(value)
    return url.protocol === "http:" || url.protocol === "https:"
  } catch {
    return false
  }
}

export function validateFields(fields: EditorFields) {
  const issues: ContentValidation[] = []
  if (fields.collection !== "quotes" && !fields.title.trim())
    issues.push({ field: "title", message: "Add a title." })
  if (!fields.slug || !/^[a-z0-9][a-z0-9-]*$/.test(fields.slug)) {
    issues.push({ field: "slug", message: "Use lowercase letters, numbers, and hyphens." })
  }
  if (fields.collection === "writing" && !/^\d{4}-\d{2}-\d{2}$/.test(fields.date)) {
    issues.push({ field: "date", message: "Choose a valid publication date." })
  }
  if (fields.collection === "quotes" && !fields.quote.trim()) {
    issues.push({ field: "quote", message: "Add the quote you want to keep." })
  }
  if (fields.collection === "links") {
    if (!httpUrl(fields.sourceUrl))
      issues.push({ field: "sourceUrl", message: "Use a full HTTP or HTTPS URL." })
    if (!fields.sourceUrl) issues.push({ field: "sourceUrl", message: "Add the original URL." })
    if (!/^[\p{L}\p{N}][\p{L}\p{N} &'()-]*$/u.test(fields.area)) {
      issues.push({ field: "area", message: "Choose a valid vault area." })
    }
    if (fields.attachments.some((attachment) => !attachmentPathFromWikilink(attachment))) {
      issues.push({ field: "attachments", message: "Remove the invalid attachment reference." })
    }
  } else if (fields.sourceUrl && !httpUrl(fields.sourceUrl)) {
    issues.push({ field: "sourceUrl", message: "Use a full HTTP or HTTPS URL." })
  }
  return issues
}

export function pathForFields(fields: EditorFields) {
  const slug = slugify(fields.slug || fields.title)
  if (!slug) return ""
  if (fields.collection === "writing") return `Writing/Blogs/${slug}.md`
  if (fields.collection === "quotes")
    return `Quotes/Entries/${fields.date || new Date().toISOString().slice(0, 10)}-${slug}.md`
  return `Areas/${fields.area}/Captures/gd-${Date.now().toString(36)}-${slug}.md`
}

export function serializeFields(fields: EditorFields, existingPath?: string) {
  const tags = cleanTags(fields.tags)
  let frontmatter: Record<string, unknown>
  if (fields.collection === "writing") {
    frontmatter = {
      contract_version: 1,
      kind: "writing",
      title: fields.title.trim(),
      slug: slugify(fields.slug || fields.title),
      date: fields.date,
      visibility: fields.visibility,
      draft: fields.draft,
      ...(fields.description.trim() ? { description: fields.description.trim() } : {}),
      tags,
    }
  } else if (fields.collection === "quotes") {
    frontmatter = {
      contract_version: 1,
      kind: "quote",
      quote: fields.quote.trim(),
      slug: slugify(fields.slug || fields.title || fields.quote.slice(0, 60)),
      ...(fields.author.trim() ? { author: fields.author.trim() } : {}),
      ...(fields.sourceName.trim() ? { source: fields.sourceName.trim() } : {}),
      ...(fields.sourceUrl.trim() ? { sourceUrl: fields.sourceUrl.trim() } : {}),
      captured_at: fields.capturedAt,
      publish: fields.publish,
      tags,
    }
  } else {
    const existingId = existingPath?.split("/").at(-1)?.replace(/\.md$/, "")
    frontmatter = {
      contract_version: 1,
      id: existingId || `gd-${Date.now().toString(36)}-${slugify(fields.slug || fields.title)}`,
      kind: "capture",
      title: fields.title.trim(),
      source: fields.sourceUrl.trim(),
      source_type: "web",
      captured_at: fields.capturedAt,
      area: `[[${fields.area}]]`,
      tags: cleanTags(["capture", ...tags]),
      metadata_status: fields.metadataStatus,
      attachments: fields.attachments,
    }
  }
  return `---\n${YAML.stringify(frontmatter, { lineWidth: 0 }).trim()}\n---\n${fields.body.trim()}\n`
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : ""
}

function tagsValue(value: unknown) {
  return Array.isArray(value) ? value.filter((tag): tag is string => typeof tag === "string") : []
}

export function fieldsFromItem(item: VaultItem): EditorFields {
  const data = item.frontmatter
  const areaMatch = item.path.match(/^Areas\/([^/]+)\//)
  const fallbackDate = new Date().toISOString().slice(0, 10)
  return {
    collection: item.collection,
    title: item.collection === "quotes" ? stringValue(data.quote).slice(0, 80) : item.title,
    slug: stringValue(data.slug) || slugify(item.title),
    body: item.body,
    description: stringValue(data.description),
    date: stringValue(data.date) || fallbackDate,
    tags: tagsValue(data.tags),
    visibility: data.visibility === "public" ? "public" : "private",
    draft: data.draft !== false,
    quote: stringValue(data.quote),
    author: stringValue(data.author),
    sourceName: item.collection === "quotes" ? stringValue(data.source) : "",
    sourceUrl: item.collection === "links" ? stringValue(data.source) : stringValue(data.sourceUrl),
    capturedAt: stringValue(data.captured_at) || new Date().toISOString(),
    publish: data.publish === true,
    area: areaMatch?.[1] || "Blogs",
    metadataStatus:
      data.metadata_status === "partial" || data.metadata_status === "pending"
        ? data.metadata_status
        : "complete",
    attachments: tagsValue(data.attachments),
  }
}

export function emptyFields(collection: CollectionKey): EditorFields {
  const now = new Date()
  return {
    collection,
    title: "",
    slug: "",
    body: "",
    description: "",
    date: now.toISOString().slice(0, 10),
    tags: [],
    visibility: "private",
    draft: true,
    quote: "",
    author: "",
    sourceName: "",
    sourceUrl: "",
    capturedAt: now.toISOString(),
    publish: false,
    area: "Blogs",
    metadataStatus: "complete",
    attachments: [],
  }
}

export function pathAllowed(filePath: string, collection: CollectionKey) {
  if (filePath.includes("..") || filePath.startsWith("/")) return false
  if (collection === "writing") return /^Writing\/[^/]+(?:\/[^/]+)*\.md$/.test(filePath)
  if (collection === "quotes") return /^Quotes\/Entries\/[^/]+\.md$/.test(filePath)
  return /^Areas\/[^/]+\/Captures\/[^/]+\.md$/.test(filePath)
}
