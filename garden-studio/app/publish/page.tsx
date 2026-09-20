import type { Metadata } from "next"
import Link from "next/link"

import { PublicationPanel } from "@/components/publication-panel"
import { StatusPill } from "@/components/status-pill"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "Review & publish" }

export default async function PublishPage() {
  const [session, snapshot] = await Promise.all([requireSession(), getVaultSnapshot()])
  const ready = snapshot.items.filter((item) => item.status === "public")
  const grouped = snapshot.collections.map((collection) => ({
    ...collection,
    items: ready.filter((item) => item.collection === collection.key),
  }))
  return (
    <StudioShell session={session} current="/publish">
      <header className="page-header">
        <div>
          <p className="eyebrow">Publication desk</p>
          <h1>Review &amp; publish</h1>
          <p>
            Build a review branch from the ready vault entries, inspect its Vercel preview, then
            explicitly merge that exact revision.
          </p>
        </div>
        <StatusPill status={snapshot.health.status} />
      </header>
      <div className="publish-layout">
        <section className="change-review" aria-labelledby="change-review-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Export boundary</p>
              <h2 id="change-review-heading">Ready to cross into Quartz</h2>
            </div>
            <span>{ready.length} total</span>
          </div>
          {grouped.map((group) => (
            <div className="review-group" key={group.key}>
              <header>
                <strong>{group.label}</strong>
                <span>{group.items.length}</span>
              </header>
              {group.items.length ? (
                <ul>
                  {group.items.map((item) => (
                    <li key={item.path}>
                      <div>
                        <strong>{item.title}</strong>
                        <small>{item.path}</small>
                      </div>
                      <Link href={`/entry?path=${encodeURIComponent(item.path)}`}>Inspect</Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <p>No ready entries.</p>
              )}
            </div>
          ))}
        </section>
        <PublicationPanel demo={snapshot.health.status === "demo"} readyCount={ready.length} />
      </div>
    </StudioShell>
  )
}
