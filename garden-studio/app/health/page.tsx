import type { Metadata } from "next"

import { StatusPill } from "@/components/status-pill"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { studioSetupChecks } from "@/lib/config-status"
import { getVaultSnapshot } from "@/lib/vault"

export const metadata: Metadata = { title: "Connection" }

export default async function HealthPage() {
  const [session, snapshot] = await Promise.all([requireSession(), getVaultSnapshot()])
  const setup = studioSetupChecks()
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
          <p>Studio shows contract health and setup state without exposing secret values.</p>
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

      <section className="health-sheet setup-sheet" aria-labelledby="setup-heading">
        <div className="health-summary">
          <span className="health-mark setup-mark" aria-hidden="true">
            ◇
          </span>
          <div>
            <h2 id="setup-heading">Deployment setup</h2>
            <p>Only presence checks are shown. Secret contents never reach this page.</p>
          </div>
        </div>
        <dl className="health-checks">
          {setup.map((check) => {
            const state = check.configured
              ? "pass"
              : session.mode === "preview"
                ? "demo"
                : "attention"
            return (
              <div key={check.label}>
                <dt>{check.label}</dt>
                <dd>{check.note}</dd>
                <span className={`check-state ${state}`}>
                  {check.configured
                    ? "Configured"
                    : session.mode === "preview"
                      ? "Demo fallback"
                      : "Missing"}
                </span>
              </div>
            )
          })}
        </dl>
      </section>

      <aside className="security-note">
        <span aria-hidden="true">◈</span>
        <div>
          <h2>Private writes, review-gated publishing</h2>
          <p>
            Editing endpoints can write only contract-backed private-vault paths. Public changes are
            built on the fixed review branch, checked in a pull request and Vercel preview, and
            require an explicit publish confirmation before merge. Destructive deletion remains
            unavailable.
          </p>
        </div>
      </aside>
    </StudioShell>
  )
}
