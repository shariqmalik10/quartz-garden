import type { Metadata } from "next"

import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "History" }

export default async function HistoryPage() {
  const [session, snapshot] = await Promise.all([requireSession(), getVaultSnapshot()])
  return (
    <StudioShell session={session} current="/history">
      <header className="page-header">
        <div>
          <p className="eyebrow">Trail of changes</p>
          <h1>Publishing history</h1>
          <p>The latest commits from the private vault and the public garden, together in time.</p>
        </div>
      </header>
      {snapshot.activity.length ? (
        <ol className="history-ledger">
          {snapshot.activity.map((activity) => (
            <li key={`${activity.repository}-${activity.sha}`}>
              <time dateTime={activity.committedAt}>
                {new Intl.DateTimeFormat("en", {
                  month: "short",
                  day: "numeric",
                  year: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                }).format(new Date(activity.committedAt))}
              </time>
              <span className={`history-source ${activity.repository}`}>
                {activity.repository === "vault" ? "Vault" : "Site"}
              </span>
              <div>
                <strong>{activity.message}</strong>
                <small>{activity.sha.slice(0, 7)}</small>
              </div>
              {activity.url && (
                <a href={activity.url} target="_blank" rel="noreferrer">
                  View commit <span aria-hidden="true">↗</span>
                </a>
              )}
            </li>
          ))}
        </ol>
      ) : (
        <div className="empty-ledger large">
          <span aria-hidden="true">↻</span>
          <p>Commit history appears when Studio reads from GitHub.</p>
        </div>
      )}
    </StudioShell>
  )
}
