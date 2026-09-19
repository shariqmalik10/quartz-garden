import type { Metadata } from "next"

import { StatusPill } from "@/components/status-pill"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "Connection" }

export default async function HealthPage() {
  const [session, snapshot] = await Promise.all([requireSession(), getVaultSnapshot()])
  const checks = [
    ["Session", session.mode === "github" ? "GitHub allowlist" : "Preview key", "pass"],
    [
      "Vault source",
      snapshot.health.source,
      snapshot.health.status === "attention" ? "attention" : "pass",
    ],
    ["Branch", snapshot.health.branch, "pass"],
    ["Revision", snapshot.health.revision, "pass"],
    ["Content contracts", `${snapshot.items.length} recognized items`, "pass"],
  ] as const
  return (
    <StudioShell session={session} current="/health">
      <header className="page-header">
        <div>
          <p className="eyebrow">System check</p>
          <h1>Connection health</h1>
          <p>Studio only reads the folders defined by the versioned content contract.</p>
        </div>
        <StatusPill status={snapshot.health.status} />
      </header>
      <section className="health-sheet" aria-labelledby="health-heading">
        <div className="health-summary">
          <span className="health-mark" aria-hidden="true">
            {snapshot.health.status === "attention" ? "!" : "✓"}
          </span>
          <div>
            <h2 id="health-heading">{snapshot.health.message}</h2>
            <p>Last checked {new Date(snapshot.health.checkedAt).toLocaleString("en")}</p>
          </div>
        </div>
        <dl className="health-checks">
          {checks.map(([label, value, state]) => (
            <div key={label}>
              <dt>{label}</dt>
              <dd>{value}</dd>
              <span className={`check-state ${state}`}>
                {state === "pass" ? "Ready" : "Needs setup"}
              </span>
            </div>
          ))}
        </dl>
      </section>
      <aside className="security-note">
        <span aria-hidden="true">◈</span>
        <div>
          <h2>Read-only by design</h2>
          <p>
            This checkpoint can inspect the allowlisted vault paths and repository history. It
            cannot create, edit, publish, merge, or delete anything.
          </p>
        </div>
      </aside>
    </StudioShell>
  )
}
