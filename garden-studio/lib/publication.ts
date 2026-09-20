import "server-only"

import { installationToken } from "./github"
import { pullMatchesPreview, summarizeChecks, type PublicationCheck } from "./publication-rules"

type RepositoryName = "vault" | "public"

function repository(name: RepositoryName) {
  const value =
    process.env[
      name === "vault" ? "GARDEN_STUDIO_VAULT_REPOSITORY" : "GARDEN_STUDIO_PUBLIC_REPOSITORY"
    ] || ""
  const [owner, repo, extra] = value.split("/")
  if (!owner || !repo || extra) throw new Error(`${name} repository is not configured`)
  return { owner, repo }
}

async function github<T>(name: RepositoryName, path: string, init?: RequestInit) {
  const { owner, repo } = repository(name)
  const response = await fetch(`https://api.github.com/repos/${owner}/${repo}${path}`, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${await installationToken()}`,
      "X-GitHub-Api-Version": "2022-11-28",
      ...(init?.headers || {}),
    },
    cache: "no-store",
  })
  if (!response.ok) {
    const detail = await response.text()
    throw new Error(
      `GitHub publication request failed (${response.status}): ${detail.slice(0, 180)}`,
    )
  }
  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}

export function previewBranch() {
  return process.env.GARDEN_STUDIO_PUBLIC_PREVIEW_BRANCH || "studio/garden-preview"
}

export async function dispatchPublication() {
  const ref = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  await github("vault", "/actions/workflows/publish-garden.yml/dispatches", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ref, inputs: { public_branch: previewBranch() } }),
  })
  return { ref, branch: previewBranch(), dispatchedAt: new Date().toISOString() }
}

export type PublicationState = {
  phase: "idle" | "queued" | "running" | "failed" | "ready" | "merged"
  runUrl?: string
  runId?: number
  branch: string
  commit?: string
  pullRequest?: { number: number; url: string; state: string; merged: boolean }
  checks: PublicationCheck[]
  previewUrl?: string
  message: string
}

async function latestRun(since?: string) {
  const branch = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const payload = await github<{
    workflow_runs: Array<{
      id: number
      html_url: string
      status: string
      conclusion: string | null
      created_at: string
    }>
  }>(
    "vault",
    `/actions/workflows/publish-garden.yml/runs?event=workflow_dispatch&branch=${encodeURIComponent(branch)}&per_page=10`,
  )
  const threshold = since ? Date.parse(since) - 30_000 : 0
  return (
    payload.workflow_runs.find((run) => Date.parse(run.created_at) >= threshold) ||
    payload.workflow_runs[0]
  )
}

async function publicHead() {
  try {
    const payload = await github<{ object: { sha: string } }>(
      "public",
      `/git/ref/heads/${previewBranch().split("/").map(encodeURIComponent).join("/")}`,
    )
    return payload.object.sha
  } catch {
    return null
  }
}

async function ensurePullRequest() {
  const { owner } = repository("public")
  const head = `${owner}:${previewBranch()}`
  const existing = await github<
    Array<{ number: number; html_url: string; state: string; merged_at: string | null }>
  >("public", `/pulls?state=all&head=${encodeURIComponent(head)}&base=main&per_page=10`)
  const open = existing.find((pull) => pull.state === "open")
  if (open) return { number: open.number, url: open.html_url, state: open.state, merged: false }
  const newest = existing[0]
  if (newest?.merged_at)
    return { number: newest.number, url: newest.html_url, state: newest.state, merged: true }
  const created = await github<{ number: number; html_url: string; state: string }>(
    "public",
    "/pulls",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: "content: preview Garden Studio changes",
        head: previewBranch(),
        base: "main",
        body: "Automated review branch from the private Obsidian vault. Merge only after the Garden Studio preview and checks pass.",
        draft: false,
      }),
    },
  )
  return { number: created.number, url: created.html_url, state: created.state, merged: false }
}

async function checksFor(commit: string) {
  const payload = await github<{
    check_runs: Array<{
      name: string
      status: string
      conclusion: string | null
      details_url?: string
    }>
  }>("public", `/commits/${commit}/check-runs?per_page=100`)
  return payload.check_runs.map((check) => ({
    name: check.name,
    status: check.status,
    conclusion: check.conclusion,
    ...(check.details_url ? { url: check.details_url } : {}),
  }))
}

async function deploymentUrl(commit: string) {
  try {
    const deployments = await github<Array<{ id: number }>>(
      "public",
      `/deployments?sha=${commit}&per_page=10`,
    )
    for (const deployment of deployments) {
      const statuses = await github<Array<{ state: string; environment_url?: string }>>(
        "public",
        `/deployments/${deployment.id}/statuses?per_page=10`,
      )
      const ready = statuses.find((status) => status.state === "success" && status.environment_url)
      if (ready?.environment_url) return ready.environment_url
    }
  } catch {
    return undefined
  }
  return undefined
}

export async function publicationStatus(since?: string): Promise<PublicationState> {
  const run = await latestRun(since)
  if (!run)
    return {
      phase: "idle",
      branch: previewBranch(),
      checks: [],
      message: "No preview run has started yet.",
    }
  if (run.status !== "completed") {
    return {
      phase: run.status === "queued" ? "queued" : "running",
      branch: previewBranch(),
      runId: run.id,
      runUrl: run.html_url,
      checks: [],
      message:
        run.status === "queued"
          ? "The private-vault export is queued."
          : "Validating and building the garden preview.",
    }
  }
  if (run.conclusion !== "success") {
    return {
      phase: "failed",
      branch: previewBranch(),
      runId: run.id,
      runUrl: run.html_url,
      checks: [],
      message: "The exporter or Quartz build failed. Nothing was merged.",
    }
  }
  const commit = await publicHead()
  if (!commit)
    return {
      phase: "running",
      branch: previewBranch(),
      runId: run.id,
      runUrl: run.html_url,
      checks: [],
      message: "The export passed; waiting for the public review branch.",
    }
  const pullRequest = await ensurePullRequest()
  const [checks, previewUrl] = await Promise.all([checksFor(commit), deploymentUrl(commit)])
  const { pending, failed } = summarizeChecks(checks)
  if (pullRequest.merged)
    return {
      phase: "merged",
      branch: previewBranch(),
      commit,
      pullRequest,
      checks,
      previewUrl,
      runId: run.id,
      runUrl: run.html_url,
      message: "This preview has been merged into the public garden.",
    }
  return {
    phase: failed ? "failed" : pending || checks.length === 0 ? "running" : "ready",
    branch: previewBranch(),
    commit,
    pullRequest,
    checks,
    previewUrl,
    runId: run.id,
    runUrl: run.html_url,
    message: failed
      ? "A public-site check failed. The preview remains unmerged."
      : pending || checks.length === 0
        ? "The public preview is still building."
        : "The preview is ready for your final review.",
  }
}

export async function mergePublication(prNumber: number) {
  const commit = await publicHead()
  if (!commit) throw new Error("The preview branch is missing")
  const checks = await checksFor(commit)
  if (!summarizeChecks(checks).ready) {
    throw new Error("Every public preview check must pass before merging")
  }
  const pull = await github<{
    number: number
    state: string
    head: { ref: string; sha: string }
    base: { ref: string }
    merged: boolean
  }>("public", `/pulls/${prNumber}`)
  if (!pullMatchesPreview(pull, previewBranch(), commit))
    throw new Error("The pull request no longer matches this preview")
  return github<{ merged: boolean; message: string; sha?: string }>(
    "public",
    `/pulls/${prNumber}/merge`,
    {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        merge_method: "squash",
        sha: commit,
        commit_title: "content: publish Garden Studio preview",
      }),
    },
  )
}
