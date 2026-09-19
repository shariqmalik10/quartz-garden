import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"

import { RevisionList } from "@/components/revision-list"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { githubConfigured } from "@/lib/github"
import { fileHistory } from "@/lib/github-write"
import { getVaultItem, getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "Revision history" }

export default async function RevisionsPage({
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
  const demo = snapshot.health.status === "demo"
  const revisions =
    demo || !githubConfigured()
      ? [
          {
            sha: "0000000000000000000000000000000000000001",
            message: "Synthetic current version",
            author: "Garden Studio",
            date: snapshot.generatedAt,
          },
        ]
      : (await fileHistory(item.path)).map((entry) => ({
          sha: entry.sha,
          message: entry.commit.message.split("\n")[0],
          author: entry.commit.author?.name || "Unknown",
          date: entry.commit.author?.date || "",
          url: entry.html_url,
        }))
  return (
    <StudioShell session={session} current={`/collection/${item.collection}`}>
      <header className="page-header">
        <div>
          <Link className="back-link" href={`/entry?path=${encodeURIComponent(item.path)}`}>
            ← Back to entry
          </Link>
          <p className="eyebrow">File history</p>
          <h1>{item.title}</h1>
          <p>Restoring never erases history. It writes the selected version as a new commit.</p>
        </div>
      </header>
      <RevisionList
        revisions={revisions}
        filePath={item.path}
        currentRevision={item.revision}
        demo={demo}
      />
    </StudioShell>
  )
}
