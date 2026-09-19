import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"

import { ContentEditor } from "@/components/content-editor"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { emptyFields } from "@/lib/content"
import type { CollectionKey } from "@/lib/types"
import { getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "New entry" }

export default async function NewEntryPage({
  searchParams,
}: {
  searchParams: Promise<{ type?: string }>
}) {
  const [{ type = "writing" }, session, snapshot] = await Promise.all([
    searchParams,
    requireSession(),
    getVaultSnapshot(),
  ])
  if (!["writing", "quotes", "links"].includes(type)) notFound()
  const collection = type as CollectionKey
  return (
    <StudioShell session={session} current={`/collection/${collection}`}>
      <header className="editor-page-heading">
        <div>
          <Link className="back-link" href={`/collection/${collection}`}>
            ← Back to collection
          </Link>
          <p className="eyebrow">New vault entry</p>
          <h1>
            {collection === "writing"
              ? "Begin a writing"
              : collection === "quotes"
                ? "Keep a quote"
                : "Save a link"}
          </h1>
        </div>
        <p>Saved as ordinary Markdown, ready to open in Obsidian.</p>
      </header>
      <ContentEditor
        initialFields={emptyFields(collection)}
        areas={snapshot.areas.map((area) => area.name)}
        linkTargets={snapshot.items.map((item) => ({ title: item.title, path: item.path }))}
        demo={snapshot.health.status === "demo"}
      />
    </StudioShell>
  )
}
