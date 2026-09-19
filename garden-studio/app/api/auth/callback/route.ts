import { timingSafeEqual } from "node:crypto"
import { cookies } from "next/headers"
import { NextResponse } from "next/server"

import { allowedLogin } from "@/lib/auth"
import { setSession } from "@/lib/session"

const STATE_COOKIE = "garden-studio-oauth-state"

function matches(left: string, right: string) {
  const a = Buffer.from(left)
  const b = Buffer.from(right)
  return a.length === b.length && timingSafeEqual(a, b)
}

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get("code") || ""
  const state = url.searchParams.get("state") || ""
  const storedState = (await cookies()).get(STATE_COOKIE)?.value || ""
  ;(await cookies()).delete(STATE_COOKIE)

  if (!code || !state || !storedState || !matches(state, storedState)) {
    return NextResponse.redirect(new URL("/login?error=invalid-state", request.url))
  }

  const clientId = process.env.GITHUB_OAUTH_CLIENT_ID
  const clientSecret = process.env.GITHUB_OAUTH_CLIENT_SECRET
  if (!clientId || !clientSecret) {
    return NextResponse.redirect(new URL("/login?error=oauth-not-configured", request.url))
  }

  const tokenResponse = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, code }),
    cache: "no-store",
  })
  const tokenPayload = (await tokenResponse.json()) as { access_token?: string }
  if (!tokenPayload.access_token) {
    return NextResponse.redirect(new URL("/login?error=oauth-failed", request.url))
  }

  const userResponse = await fetch("https://api.github.com/user", {
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${tokenPayload.access_token}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
    cache: "no-store",
  })
  const user = (await userResponse.json()) as { login?: string; name?: string; avatar_url?: string }
  if (!user.login || user.login.toLowerCase() !== allowedLogin()) {
    return NextResponse.redirect(new URL("/login?error=not-allowed", request.url))
  }

  await setSession({
    login: user.login,
    name: user.name || user.login,
    avatarUrl: user.avatar_url,
    mode: "github",
  })
  return NextResponse.redirect(new URL("/", request.url))
}
