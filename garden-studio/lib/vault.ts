import "server-only"

import { cache } from "react"
import { existsSync } from "node:fs"
import { readFile, readdir, stat } from "node:fs/promises"
import path from "node:path"
import YAML from "yaml"

import { areasFromDocuments } from "./areas"
import { githubConfigured, readBlobs, readRecentCommits, readRepositoryTree } from "./github"
import type {
  ActivityItem,
  CollectionKey,
  CollectionSummary,
  ItemStatus,
  VaultItem,
  VaultSnapshot,
} from "./types"

const COLLECTION_LABELS: Record<CollectionKey, { label: string; description: string }> = {
  writing: { label: "Writing", description: "Drafts, essays, and public notes." },
  quotes: { label: "Quotes", description: "Lines collected for the garden margin." },
  links: { label: "Saved links", description: "Blogs and references grouped by area." },
}

type SourceDocument = { path: string; content: string; modifiedAt?: string; revision?: string }

function parseMarkdown(content: string) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)([\s\S]*)$/)
  if (!match) return { frontmatter: {} as Record<string, unknown>, body: content }
  const frontmatter = YAML.parse(match[1])
  return {
    frontmatter:
      typeof frontmatter === "object" && frontmatter !== null && !Array.isArray(frontmatter)
        ? (frontmatter as Record<string, unknown>)
        : {},
    body: match[2].trim(),
  }
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : ""
}

function titleFromPath(filePath: string) {
  return path.basename(filePath, path.extname(filePath)).replaceAll("-", " ")
}

function statusForWriting(data: Record<string, unknown>): ItemStatus {
  if (data.visibility === "public" && data.draft === false) return "public"
  return data.draft === true ? "draft" : "private"
}

function sourcePaths(filePaths: string[]) {
  return filePaths.filter(
    (filePath) =>
      /^Areas\/[^/]+\/[^/]+\.md$/.test(filePath) ||
      /^Areas\/[^/]+\/Captures\/[^/]+\.md$/.test(filePath) ||
      /^Quotes\/(Quotes\.md|Entries\/[^/]+\.md)$/.test(filePath) ||
      /^Writing\/.+\.md$/.test(filePath),
  )
}

function documentsToItems(documents: SourceDocument[]) {
  const parsed = new Map(
    documents.map((document) => [
      document.path,
      { ...document, ...parseMarkdown(document.content) },
    ]),
  )
  const areaVisibility = new Map<string, string>()
  for (const [filePath, document] of parsed) {
    const match = filePath.match(/^Areas\/([^/]+)\/\1\.md$/)
    if (match) areaVisibility.set(match[1], stringValue(document.frontmatter.visibility))
  }

  const items: VaultItem[] = []
  for (const [filePath, document] of parsed) {
    const data = document.frontmatter
    const captureMatch = filePath.match(/^Areas\/([^/]+)\/Captures\/[^/]+\.md$/)
    if (captureMatch && data.kind === "capture") {
      const area = captureMatch[1]
      items.push({
        collection: "links",
        path: filePath,
        title: stringValue(data.title) || titleFromPath(filePath),
        status: areaVisibility.get(area) === "garden" ? "public" : "private",
        detail: stringValue(data.source) || area,
        modifiedAt: document.modifiedAt,
        revision: document.revision,
        body: document.body,
        frontmatter: data,
      })
      continue
    }
    if (/^Quotes\/Entries\//.test(filePath) && data.kind === "quote") {
      items.push({
        collection: "quotes",
        path: filePath,
        title: stringValue(data.quote) || titleFromPath(filePath),
        status: data.publish === true ? "public" : "draft",
        detail: stringValue(data.author) || stringValue(data.source) || "Unattributed",
        modifiedAt: document.modifiedAt,
        revision: document.revision,
        body: document.body,
        frontmatter: data,
      })
      continue
    }
    if (/^Writing\//.test(filePath) && data.kind === "writing") {
      items.push({
        collection: "writing",
        path: filePath,
        title: stringValue(data.title) || titleFromPath(filePath),
        status: statusForWriting(data),
        detail: stringValue(data.description) || stringValue(data.date) || "Working note",
        modifiedAt: document.modifiedAt,
        revision: document.revision,
        body: document.body,
        frontmatter: data,
      })
    }
  }
  return items.toSorted((a, b) =>
    (
      b.modifiedAt ||
      stringValue(b.frontmatter.captured_at) ||
      stringValue(b.frontmatter.date)
    ).localeCompare(
      a.modifiedAt || stringValue(a.frontmatter.captured_at) || stringValue(a.frontmatter.date),
    ),
  )
}

function summarize(items: VaultItem[]): CollectionSummary[] {
  return (Object.keys(COLLECTION_LABELS) as CollectionKey[]).map((key) => {
    const collectionItems = items.filter((item) => item.collection === key)
    return {
      key,
      ...COLLECTION_LABELS[key],
      total: collectionItems.length,
      public: collectionItems.filter((item) => item.status === "public").length,
      draft: collectionItems.filter((item) => item.status === "draft").length,
      private: collectionItems.filter((item) => item.status === "private").length,
    }
  })
}

async function localDocuments(root: string) {
  const documents: SourceDocument[] = []
  async function walk(relativeDirectory: string) {
    const absoluteDirectory = path.join(root, relativeDirectory)
    if (!existsSync(absoluteDirectory)) return
    for (const entry of await readdir(absoluteDirectory, { withFileTypes: true })) {
      if (entry.name.startsWith(".") || entry.isSymbolicLink()) continue
      const relativePath = path.posix.join(relativeDirectory.split(path.sep).join("/"), entry.name)
      const absolutePath = path.join(root, relativePath)
      if (entry.isDirectory()) await walk(relativePath)
      else if (entry.isFile() && entry.name.endsWith(".md")) {
        const metadata = await stat(absolutePath)
        documents.push({
          path: relativePath,
          content: await readFile(absolutePath, "utf8"),
          modifiedAt: metadata.mtime.toISOString(),
          revision: String(metadata.mtimeMs),
        })
      }
    }
  }
  await Promise.all([walk("Areas"), walk("Quotes"), walk("Writing")])
  return documents.filter((document) => sourcePaths([document.path]).length > 0)
}

function demoSnapshot(): VaultSnapshot {
  const now = new Date().toISOString()
  const items: VaultItem[] = [
    {
      collection: "writing",
      path: "Writing/Blogs/a-small-web.md",
      title: "A small web worth returning to",
      status: "draft",
      detail: "A working note about attention and personal software.",
      body: "This is synthetic preview content used to review the read-only Studio interface.",
      frontmatter: { kind: "writing", visibility: "private", draft: true, date: "2026-09-19" },
      revision: "demo-writing-1",
    },
    {
      collection: "quotes",
      path: "Quotes/Entries/flowers.md",
      title: "What happens to flowers that no one buys? They bloom regardless.",
      status: "public",
      detail: "Unattributed",
      body: "",
      frontmatter: { kind: "quote", publish: true },
      revision: "demo-quote-1",
    },
    {
      collection: "links",
      path: "Areas/Blogs/Captures/gd-preview.md",
      title: "A field guide to quiet interfaces",
      status: "public",
      detail: "https://example.com/quiet-interfaces",
      body: "Saved as synthetic preview data.",
      frontmatter: { kind: "capture", source: "https://example.com/quiet-interfaces" },
      revision: "demo-link-1",
    },
  ]
  return {
    generatedAt: now,
    health: {
      status: "demo",
      source: "Synthetic review fixture",
      branch: "preview",
      revision: "demo000",
      checkedAt: now,
      message: "No private vault content is loaded in preview mode.",
    },
    collections: summarize(items),
    areas: [
      { name: "Blogs", visibility: "garden", mediaPolicy: "reference" },
      { name: "Design & Interaction", visibility: "garden", mediaPolicy: "owned" },
    ],
    items,
    activity: [
      {
        sha: "demo000",
        message: "Preview the read-only Garden Studio",
        committedAt: now,
        repository: "vault",
      },
    ],
  }
}

async function githubSnapshot(): Promise<VaultSnapshot> {
  const [tree, vaultCommits, siteCommits] = await Promise.all([
    readRepositoryTree(),
    readRecentCommits("vault"),
    readRecentCommits("public"),
  ])
  const treeItems = tree.tree.filter(
    (item) => item.type === "blob" && sourcePaths([item.path]).length > 0,
  )
  const blobs = await readBlobs(treeItems)
  const documents = treeItems.map((item) => ({
    path: item.path,
    content: blobs.get(item.path) || "",
    revision: item.sha,
  }))
  const items = documentsToItems(documents)
  const activity: ActivityItem[] = [
    ...vaultCommits.map((item) => ({
      sha: item.sha,
      message: item.commit.message.split("\n")[0],
      committedAt: item.commit.committer?.date || "",
      repository: "vault" as const,
      url: item.html_url,
    })),
    ...siteCommits.map((item) => ({
      sha: item.sha,
      message: item.commit.message.split("\n")[0],
      committedAt: item.commit.committer?.date || "",
      repository: "site" as const,
      url: item.html_url,
    })),
  ].toSorted((a, b) => b.committedAt.localeCompare(a.committedAt))

  const now = new Date().toISOString()
  return {
    generatedAt: now,
    health: {
      status: "connected",
      source: process.env.GARDEN_STUDIO_VAULT_REPOSITORY || "private vault",
      branch: tree.branch,
      revision: tree.revision.slice(0, 7),
      checkedAt: now,
      message: "GitHub App connection is healthy.",
    },
    collections: summarize(items),
    areas: areasFromDocuments(documents),
    items,
    activity,
  }
}

async function localSnapshot(root: string): Promise<VaultSnapshot> {
  const documents = await localDocuments(root)
  const items = documentsToItems(documents)
  const now = new Date().toISOString()
  return {
    generatedAt: now,
    health: {
      status: "connected",
      source: root,
      branch: "local",
      revision: "working tree",
      checkedAt: now,
      message: "Reading the local vault; browser writes stay disabled in local mode.",
    },
    collections: summarize(items),
    areas: areasFromDocuments(documents),
    items,
    activity: [],
  }
}

async function loadSnapshot(): Promise<VaultSnapshot> {
  if (process.env.GARDEN_STUDIO_DEMO === "true") return demoSnapshot()
  const localRoot = process.env.GARDEN_STUDIO_LOCAL_VAULT
  if (localRoot && process.env.VERCEL !== "1") return localSnapshot(path.resolve(localRoot))
  if (githubConfigured()) return githubSnapshot()
  const snapshot = demoSnapshot()
  snapshot.health.status = "attention"
  snapshot.health.message =
    "Configure the GitHub App to read the private vault. Demo data is shown."
  return snapshot
}

export const getVaultSnapshot = cache(loadSnapshot)

export async function getVaultItem(filePath: string) {
  if (!sourcePaths([filePath]).includes(filePath)) return null
  return (await getVaultSnapshot()).items.find((item) => item.path === filePath) ?? null
}
