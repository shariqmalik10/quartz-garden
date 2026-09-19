import "server-only"

import { installationToken } from "./github"

export class RepositoryConflictError extends Error {
  constructor(message = "The file changed after this editor opened.") {
    super(message)
    this.name = "RepositoryConflictError"
  }
}

function vaultRepository() {
  const value = process.env.GARDEN_STUDIO_VAULT_REPOSITORY || ""
  const [owner, repo, extra] = value.split("/")
  if (!owner || !repo || extra) throw new Error("GARDEN_STUDIO_VAULT_REPOSITORY is not configured")
  return { owner, repo }
}

function encodedPath(filePath: string) {
  return filePath.split("/").map(encodeURIComponent).join("/")
}

async function request(url: string, init?: RequestInit) {
  return fetch(url, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${await installationToken()}`,
      "X-GitHub-Api-Version": "2022-11-28",
      ...(init?.headers || {}),
    },
    cache: "no-store",
  })
}

export async function readVaultFile(filePath: string, ref?: string) {
  const { owner, repo } = vaultRepository()
  const branch = ref || process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const response = await request(
    `https://api.github.com/repos/${owner}/${repo}/contents/${encodedPath(filePath)}?ref=${encodeURIComponent(branch)}`,
  )
  if (response.status === 404) return null
  if (!response.ok) throw new Error(`GitHub file read failed (${response.status})`)
  const payload = (await response.json()) as { sha: string; content: string; encoding: string }
  if (payload.encoding !== "base64") throw new Error("GitHub returned an unexpected file encoding")
  return {
    sha: payload.sha,
    content: Buffer.from(payload.content.replaceAll("\n", ""), "base64").toString("utf8"),
  }
}

export async function writeVaultFile({
  filePath,
  content,
  expectedRevision,
  message,
}: {
  filePath: string
  content: string
  expectedRevision?: string
  message: string
}) {
  const { owner, repo } = vaultRepository()
  const branch = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const response = await request(
    `https://api.github.com/repos/${owner}/${repo}/contents/${encodedPath(filePath)}`,
    {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message,
        content: Buffer.from(content).toString("base64"),
        branch,
        ...(expectedRevision ? { sha: expectedRevision } : {}),
      }),
    },
  )
  if (response.status === 409 || response.status === 422) throw new RepositoryConflictError()
  if (!response.ok) throw new Error(`GitHub file write failed (${response.status})`)
  const payload = (await response.json()) as {
    content?: { sha?: string }
    commit?: { sha?: string }
  }
  return { revision: payload.content?.sha || "", commit: payload.commit?.sha || "" }
}

export async function fileHistory(filePath: string, limit = 20) {
  const { owner, repo } = vaultRepository()
  const branch = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const response = await request(
    `https://api.github.com/repos/${owner}/${repo}/commits?sha=${encodeURIComponent(branch)}&path=${encodeURIComponent(filePath)}&per_page=${limit}`,
  )
  if (!response.ok) throw new Error(`GitHub history read failed (${response.status})`)
  return (await response.json()) as Array<{
    sha: string
    html_url: string
    commit: { message: string; author: { name: string; date: string } | null }
  }>
}
