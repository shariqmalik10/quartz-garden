import { importPKCS8, SignJWT } from "jose"

type GitHubTreeItem = {
  path: string
  mode: string
  type: "blob" | "tree"
  sha: string
  size?: number
}

type InstallationToken = { token: string; expiresAt: number }
let cachedInstallationToken: InstallationToken | null = null

function required(name: string) {
  const value = process.env[name]
  if (!value) throw new Error(`${name} is not configured`)
  return value
}

function repository(name: "vault" | "public") {
  const value =
    name === "vault"
      ? required("GARDEN_STUDIO_VAULT_REPOSITORY")
      : required("GARDEN_STUDIO_PUBLIC_REPOSITORY")
  const [owner, repo, extra] = value.split("/")
  if (!owner || !repo || extra) throw new Error(`${name} repository must use owner/name format`)
  return { owner, repo }
}

async function appJwt() {
  const appId = required("GITHUB_APP_ID")
  const privateKey = required("GITHUB_APP_PRIVATE_KEY").replaceAll("\\n", "\n")
  const key = await importPKCS8(privateKey, "RS256")
  const now = Math.floor(Date.now() / 1000)
  return new SignJWT({})
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(appId)
    .setIssuedAt(now - 30)
    .setExpirationTime(now + 8 * 60)
    .sign(key)
}

async function installationToken() {
  if (cachedInstallationToken && cachedInstallationToken.expiresAt > Date.now() + 60_000) {
    return cachedInstallationToken.token
  }
  const installationId = required("GITHUB_APP_INSTALLATION_ID")
  const response = await fetch(
    `https://api.github.com/app/installations/${encodeURIComponent(installationId)}/access_tokens`,
    {
      method: "POST",
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${await appJwt()}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
      cache: "no-store",
    },
  )
  if (!response.ok) throw new Error(`GitHub App token request failed (${response.status})`)
  const payload = (await response.json()) as { token: string; expires_at: string }
  cachedInstallationToken = { token: payload.token, expiresAt: Date.parse(payload.expires_at) }
  return payload.token
}

async function githubJson<T>(url: string): Promise<T> {
  const response = await fetch(url, {
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${await installationToken()}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
    next: { revalidate: 60 },
  })
  if (!response.ok) throw new Error(`GitHub read failed (${response.status}) for ${url}`)
  return response.json() as Promise<T>
}

export function githubConfigured() {
  return Boolean(
    process.env.GITHUB_APP_ID &&
    process.env.GITHUB_APP_INSTALLATION_ID &&
    process.env.GITHUB_APP_PRIVATE_KEY &&
    process.env.GARDEN_STUDIO_VAULT_REPOSITORY &&
    process.env.GARDEN_STUDIO_PUBLIC_REPOSITORY,
  )
}

export async function readRepositoryTree() {
  const { owner, repo } = repository("vault")
  const branch = process.env.GARDEN_STUDIO_VAULT_BRANCH || "main"
  const payload = await githubJson<{ sha: string; tree: GitHubTreeItem[]; truncated: boolean }>(
    `https://api.github.com/repos/${owner}/${repo}/git/trees/${encodeURIComponent(branch)}?recursive=1`,
  )
  if (payload.truncated) throw new Error("The vault tree was truncated by GitHub")
  return { branch, revision: payload.sha, tree: payload.tree }
}

export async function readBlobs(items: GitHubTreeItem[]) {
  const { owner, repo } = repository("vault")
  const results = new Map<string, string>()
  const batchSize = 8
  for (let index = 0; index < items.length; index += batchSize) {
    const batch = items.slice(index, index + batchSize)
    const values = await Promise.all(
      batch.map(async (item) => {
        const blob = await githubJson<{ content: string; encoding: string }>(
          `https://api.github.com/repos/${owner}/${repo}/git/blobs/${item.sha}`,
        )
        if (blob.encoding !== "base64") throw new Error(`Unexpected encoding for ${item.path}`)
        return [
          item.path,
          Buffer.from(blob.content.replaceAll("\n", ""), "base64").toString("utf8"),
        ] as const
      }),
    )
    for (const [filePath, content] of values) results.set(filePath, content)
  }
  return results
}

export async function readRecentCommits(name: "vault" | "public", limit = 6) {
  const { owner, repo } = repository(name)
  const branch = name === "vault" ? process.env.GARDEN_STUDIO_VAULT_BRANCH || "main" : "main"
  return githubJson<
    Array<{
      sha: string
      html_url: string
      commit: { message: string; committer: { date: string } | null }
    }>
  >(
    `https://api.github.com/repos/${owner}/${repo}/commits?sha=${encodeURIComponent(branch)}&per_page=${limit}`,
  )
}
