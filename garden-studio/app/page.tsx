import Link from "next/link"

import { ItemLedger } from "@/components/item-ledger"
import { StatusPill } from "@/components/status-pill"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { getVaultSnapshot } from "@/lib/vault"

function relativeTime(value: string) {
  const minutes = Math.round((Date.now() - new Date(value).valueOf()) / 60_000)
  if (!Number.isFinite(minutes)) return "Unknown"
  if (minutes < 2) return "Just now"
  if (minutes < 60) return `${minutes}m ago`
  if (minutes < 1_440) return `${Math.round(minutes / 60)}h ago`
  return `${Math.round(minutes / 1_440)}d ago`
}

export default async function DashboardPage() {
  const [session, snapshot] = await Promise.all([requireSession(), getVaultSnapshot()])
  const recent = snapshot.items.slice(0, 6)
  return (
    <StudioShell session={session} current="/">
      <header className="page-header">
        <div>
          <p className="eyebrow">Today in the garden</p>
          <h1>Publishing overview</h1>
          <p>See what is growing, what stays private, and whether the path to the site is clear.</p>
        </div>
        <div className="header-tools">
          <div className="quick-create">
            <Link href="/new?type=writing">New writing</Link>
            <Link href="/new?type=quotes">Add quote</Link>
            <Link href="/new?type=links">Save link</Link>
            <Link href="/publish">Review changes</Link>
          </div>
          <span className="header-date">
            {new Intl.DateTimeFormat("en", {
              weekday: "long",
              month: "long",
              day: "numeric",
            }).format(new Date())}
          </span>
        </div>
      </header>

      <section className="source-strip" aria-labelledby="source-heading">
        <span className="source-signal" aria-hidden="true" />
        <div>
          <p id="source-heading">Vault source</p>
          <strong>{snapshot.health.source}</strong>
        </div>
        <dl>
          <div>
            <dt>Branch</dt>
            <dd>{snapshot.health.branch}</dd>
          </div>
          <div>
            <dt>Revision</dt>
            <dd>{snapshot.health.revision}</dd>
          </div>
          <div>
            <dt>Checked</dt>
            <dd>{relativeTime(snapshot.health.checkedAt)}</dd>
          </div>
        </dl>
        <StatusPill status={snapshot.health.status} />
        <Link href="/health" className="strip-link">
          Inspect <span aria-hidden="true">→</span>
        </Link>
      </section>

      <div className="dashboard-grid">
        <div className="dashboard-primary">
          <section aria-labelledby="collections-heading">
            <div className="section-heading">
              <div>
                <p className="eyebrow">The ledger</p>
                <h2 id="collections-heading">Collections</h2>
              </div>
              <span>{snapshot.items.length} items in view</span>
            </div>
            <div className="collection-ledger">
              <div className="collection-heading" aria-hidden="true">
                <span>Collection</span>
                <span>Public</span>
                <span>Draft</span>
                <span>Private</span>
              </div>
              {snapshot.collections.map((collection) => (
                <Link
                  href={`/collection/${collection.key}`}
                  className="collection-row"
                  key={collection.key}
                >
                  <span className="collection-name">
                    <strong>{collection.label}</strong>
                    <small>{collection.description}</small>
                  </span>
                  <span>{collection.public}</span>
                  <span>{collection.draft}</span>
                  <span>{collection.private}</span>
                  <span className="row-arrow" aria-hidden="true">
                    →
                  </span>
                </Link>
              ))}
            </div>
          </section>

          <section aria-labelledby="recent-heading">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Across the vault</p>
                <h2 id="recent-heading">Recently tended</h2>
              </div>
            </div>
            <ItemLedger items={recent} compact />
          </section>
        </div>

        <aside className="activity-rail" aria-labelledby="activity-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Trail of changes</p>
              <h2 id="activity-heading">Recent activity</h2>
            </div>
          </div>
          {snapshot.activity.length ? (
            <ol className="activity-list">
              {snapshot.activity.slice(0, 6).map((activity) => (
                <li key={`${activity.repository}-${activity.sha}`}>
                  <span className={`activity-dot ${activity.repository}`} aria-hidden="true" />
                  <p>{activity.message}</p>
                  <small>
                    {activity.repository === "vault" ? "Vault" : "Site"} ·{" "}
                    {relativeTime(activity.committedAt)}
                  </small>
                </li>
              ))}
            </ol>
          ) : (
            <p className="rail-empty">Local mode has no commit history to show.</p>
          )}
          <Link className="rail-link" href="/history">
            View full history <span aria-hidden="true">→</span>
          </Link>
        </aside>
      </div>
    </StudioShell>
  )
}
