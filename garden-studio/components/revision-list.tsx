"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"

type Revision = { sha: string; message: string; author: string; date: string; url?: string }

export function RevisionList({
  revisions,
  filePath,
  currentRevision,
  demo,
}: {
  revisions: Revision[]
  filePath: string
  currentRevision?: string
  demo: boolean
}) {
  const router = useRouter()
  const [working, setWorking] = useState<string | null>(null)
  const [notice, setNotice] = useState("")

  async function restore(revision: Revision) {
    if (
      !window.confirm(
        `Restore “${revision.message}” as a new commit? Your current version stays in history.`,
      )
    )
      return
    setWorking(revision.sha)
    setNotice("Restoring…")
    const response = await fetch("/api/content/restore", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        path: filePath,
        targetRevision: revision.sha,
        expectedRevision: currentRevision,
      }),
    })
    const result = (await response.json()) as { message?: string }
    setNotice(result.message || (response.ok ? "Restored." : "Restore failed."))
    setWorking(null)
    if (response.ok && !demo) router.refresh()
  }

  return (
    <>
      <p className="revision-notice" aria-live="polite">
        {notice}
      </p>
      <ol className="revision-list">
        {revisions.map((revision, index) => (
          <li key={revision.sha}>
            <span className="revision-index">{String(index + 1).padStart(2, "0")}</span>
            <div>
              <strong>{revision.message}</strong>
              <small>
                {revision.author} ·{" "}
                {new Intl.DateTimeFormat("en", {
                  month: "short",
                  day: "numeric",
                  year: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                }).format(new Date(revision.date))}
              </small>
            </div>
            <code>{revision.sha.slice(0, 7)}</code>
            {index === 0 ? (
              <span className="current-revision">Current</span>
            ) : (
              <button
                type="button"
                onClick={() => void restore(revision)}
                disabled={working !== null}
              >
                {working === revision.sha ? "Restoring…" : "Restore"}
              </button>
            )}
            {revision.url && (
              <a
                href={revision.url}
                target="_blank"
                rel="noreferrer"
                aria-label={`View ${revision.sha.slice(0, 7)} on GitHub`}
              >
                ↗
              </a>
            )}
          </li>
        ))}
      </ol>
    </>
  )
}
