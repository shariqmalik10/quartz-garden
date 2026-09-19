"use client"

import { useEffect, useState } from "react"

import type { PublicationState } from "@/lib/publication"

const initial: PublicationState = {
  phase: "idle",
  branch: "studio/garden-preview",
  checks: [],
  message: "No preview run has started yet.",
}

export function PublicationPanel({ demo, readyCount }: { demo: boolean; readyCount: number }) {
  const [state, setState] = useState<PublicationState>(initial)
  const [since, setSince] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [confirmation, setConfirmation] = useState("")
  const [error, setError] = useState("")

  useEffect(() => {
    if (!since || !["queued", "running"].includes(state.phase)) return
    const poll = window.setInterval(async () => {
      const response = await fetch(`/api/publish/status?since=${encodeURIComponent(since)}`, {
        cache: "no-store",
      })
      if (response.ok) setState((await response.json()) as PublicationState)
    }, 5000)
    return () => window.clearInterval(poll)
  }, [since, state.phase])

  async function beginPreview() {
    setBusy(true)
    setError("")
    const response = await fetch("/api/publish/preview", { method: "POST" })
    const result = (await response.json()) as { dispatchedAt?: string; message?: string }
    if (!response.ok || !result.dispatchedAt) {
      setError(result.message || "The preview could not start.")
      setBusy(false)
      return
    }
    setSince(result.dispatchedAt)
    setState({ ...initial, phase: "queued", message: result.message || "Preview queued." })
    const status = await fetch(
      `/api/publish/status?since=${encodeURIComponent(result.dispatchedAt)}`,
      { cache: "no-store" },
    )
    if (status.ok) setState((await status.json()) as PublicationState)
    setBusy(false)
  }

  async function refresh() {
    setBusy(true)
    const response = await fetch(
      `/api/publish/status${since ? `?since=${encodeURIComponent(since)}` : ""}`,
      { cache: "no-store" },
    )
    if (response.ok) setState((await response.json()) as PublicationState)
    setBusy(false)
  }

  async function merge() {
    if (!state.pullRequest) return
    setBusy(true)
    setError("")
    const response = await fetch("/api/publish/merge", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pullRequest: state.pullRequest.number, confirmation }),
    })
    const result = (await response.json()) as { message?: string }
    if (!response.ok) setError(result.message || "The preview was not merged.")
    else
      setState((current) => ({
        ...current,
        phase: "merged",
        message: result.message || "Published.",
      }))
    setBusy(false)
  }

  const activeStep =
    state.phase === "idle"
      ? 1
      : ["queued", "running", "failed"].includes(state.phase)
        ? 2
        : state.phase === "ready"
          ? 3
          : 4
  return (
    <section className="publication-console" aria-labelledby="publish-console-heading">
      <div className="publish-progress" aria-label="Publication progress">
        {["Review", "Build preview", "Approve", "Published"].map((label, index) => (
          <div
            className={index + 1 < activeStep ? "done" : index + 1 === activeStep ? "active" : ""}
            key={label}
          >
            <span>{index + 1 < activeStep ? "✓" : index + 1}</span>
            <small>{label}</small>
          </div>
        ))}
      </div>
      <div className="publication-status">
        <div>
          <p className="eyebrow">Current state</p>
          <h2 id="publish-console-heading">{state.message}</h2>
          <p>
            {readyCount} ready {readyCount === 1 ? "entry" : "entries"} will be exported from the
            private vault. Drafts and private notes stay behind.
          </p>
        </div>
        <span className={`publish-state state-${state.phase}`}>{state.phase}</span>
      </div>
      {error && (
        <p className="form-notice error" role="alert">
          {error}
        </p>
      )}
      {(state.runUrl || state.pullRequest || state.previewUrl) && (
        <p className="publish-link-row">
          {state.runUrl && (
            <a href={state.runUrl} target="_blank" rel="noreferrer">
              View exporter run ↗
            </a>
          )}
          {state.pullRequest && (
            <a href={state.pullRequest.url} target="_blank" rel="noreferrer">
              Review pull request #{state.pullRequest.number} ↗
            </a>
          )}
          {state.previewUrl && (
            <a href={state.previewUrl} target="_blank" rel="noreferrer">
              Open website preview ↗
            </a>
          )}
        </p>
      )}
      {state.checks.length > 0 && (
        <ul className="publish-checks">
          {state.checks.map((check) => (
            <li key={check.name}>
              <span
                className={
                  check.conclusion === "success"
                    ? "pass"
                    : check.status === "completed"
                      ? "fail"
                      : "wait"
                }
              >
                {check.conclusion === "success" ? "✓" : check.status === "completed" ? "!" : "…"}
              </span>
              <strong>{check.name}</strong>
              <small>{check.conclusion || check.status}</small>
              {check.url && (
                <a
                  href={check.url}
                  target="_blank"
                  rel="noreferrer"
                  aria-label={`Open ${check.name}`}
                >
                  ↗
                </a>
              )}
            </li>
          ))}
        </ul>
      )}
      <div className="publish-actions">
        {state.phase === "idle" || state.phase === "failed" ? (
          <button
            className="primary-button"
            type="button"
            onClick={() => void beginPreview()}
            disabled={busy || readyCount === 0}
          >
            {busy ? "Starting…" : "Build website preview"}
          </button>
        ) : (
          <button
            className="secondary-button"
            type="button"
            onClick={() => void refresh()}
            disabled={busy}
          >
            {busy ? "Checking…" : "Refresh status"}
          </button>
        )}
        {state.phase === "ready" && (
          <div className="merge-confirm">
            <label htmlFor="publish-confirmation">
              Type <strong>publish</strong> to merge this exact preview
            </label>
            <div>
              <input
                id="publish-confirmation"
                value={confirmation}
                onChange={(event) => setConfirmation(event.target.value)}
                autoComplete="off"
              />
              <button
                className="primary-button"
                type="button"
                onClick={() => void merge()}
                disabled={busy || confirmation !== "publish" || demo}
              >
                {demo ? "Merge disabled in demo" : busy ? "Publishing…" : "Publish to garden"}
              </button>
            </div>
          </div>
        )}
      </div>
      <p className="publish-safety">
        <span aria-hidden="true">◈</span> Preview never changes the production site. Only the final
        confirmed merge can publish.
      </p>
    </section>
  )
}
