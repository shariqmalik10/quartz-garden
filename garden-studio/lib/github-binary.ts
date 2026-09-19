import "server-only"

import { installationToken } from "./github"

function repository() {
  const value = process.env.GARDEN_STUDIO_VAULT_REPOSITORY || ""
  const [owner, repo, extra] = value.split("/")
  if (!owner || !repo || extra) throw new Error("GARDEN_STUDIO_VAULT_REPOSITORY is not configured")
  return { owner, repo }
}

function encodedPath(filePath: string) {
  return filePath.split("/").map(encodeURIComponent).join("/")
}

async function request(filePath: string, init?: RequestInit, ref?: string) {
  const { owner, repo } = repository()
  return fetch(
    `https://api.github.com/repos/${owner}/${repo}/contents/${encodedPath(filePath)}${ref ? `?ref=${encodeURIComponent(ref)}` : ""}`,
    {
      ...init,
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${await installationToken()}`,
        "X-GitHub-Api-Version": "2022-11-28",
        ...(init?.headers || {}),
      },
      cache: "no-store",
    },
  )
}

export async function writeVaultBinary(filePath: string, bytes: Uint8Array) {
  const branch = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const response = await request(filePath, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: `Add capture attachment: ${filePath.split("/").at(-1)}`,
      content: Buffer.from(bytes).toString("base64"),
      branch,
    }),
  })
  if (response.status === 409 || response.status === 422)
    throw new Error("An attachment already uses this path. Try the upload again.")
  if (!response.ok) throw new Error(`GitHub attachment write failed (${response.status})`)
  return (await response.json()) as { content?: { sha?: string }; commit?: { sha?: string } }
}

export async function readVaultBinary(filePath: string) {
  const branch = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const response = await request(filePath, undefined, branch)
  if (response.status === 404) return null
  if (!response.ok) throw new Error(`GitHub attachment read failed (${response.status})`)
  const payload = (await response.json()) as { content: string; encoding: string }
  if (payload.encoding !== "base64") throw new Error("GitHub returned an unexpected file encoding")
  return Uint8Array.from(Buffer.from(payload.content.replaceAll("\n", ""), "base64"))
}
