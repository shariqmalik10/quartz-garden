import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"

import { ContentEditor } from "@/components/content-editor"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { fieldsFromItem } from "@/lib/content"
import { getVaultItem, getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "Edit entry" }

export default async function EditEntryPage({
  searchParams,
}: {
  searchParams: Promise<{ path?: string }>
}) {
  const [{ path = "" }, session, snapshot] = await Promise.all([
    searchParams,
    requireSession(),
    getVaultSnapshot(),
  ])
  const item = await getVaultItem(path)
  if (!item) notFound()
  const vaultName = process.env.GARDEN_STUDIO_OBSIDIAN_VAULT_NAME || "Obsidian Vault"
  const obsidianUri = `obsidian://open?vault=${encodeURIComponent(vaultName)}&file=${encodeURIComponent(item.path.replace(/\.md$/, ""))}`
  return (
    <StudioShell session={session} current={`/collection/${item.collection}`}>
      <header className="editor-page-heading">
        <div>
          <Link className="back-link" href={`/entry?path=${encodeURIComponent(item.path)}`}>
            ← Back to inspection
          </Link>
          <p className="eyebrow">Editing private vault source</p>
          <h1>{item.title}</h1>
        </div>
        <p>Every save creates a Git commit and remains compatible with Obsidian.</p>
      </header>
      <ContentEditor
        initialFields={fieldsFromItem(item)}
        originalPath={item.path}
        initialRevision={item.revision}
        areas={snapshot.areas.map((area) => area.name)}
        demo={snapshot.health.status === "demo"}
        obsidianUri={obsidianUri}
      />
    </StudioShell>
  )
}
