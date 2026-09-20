export type PublicationCheck = {
  name: string
  status: string
  conclusion: string | null
  url?: string
}

const PASSING_CONCLUSIONS = new Set(["success", "neutral", "skipped"])

export function summarizeChecks(checks: PublicationCheck[]) {
  if (checks.length === 0) return { ready: false, pending: true, failed: false }
  const pending = checks.some((check) => check.status !== "completed")
  const failed = checks.some(
    (check) => check.status === "completed" && !PASSING_CONCLUSIONS.has(check.conclusion || ""),
  )
  return { ready: !pending && !failed, pending, failed }
}

export function pullMatchesPreview(
  pull: {
    state: string
    head: { ref: string; sha: string }
    base: { ref: string }
  },
  branch: string,
  commit: string,
) {
  return (
    pull.state === "open" &&
    pull.head.ref === branch &&
    pull.head.sha === commit &&
    pull.base.ref === "main"
  )
}
