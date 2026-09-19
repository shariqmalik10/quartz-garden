import { randomBytes } from "node:crypto"
import { cookies } from "next/headers"
import { NextResponse } from "next/server"

const STATE_COOKIE = "garden-studio-oauth-state"

export async function GET(request: Request) {
  const clientId = process.env.GITHUB_OAUTH_CLIENT_ID
  if (!clientId)
    return NextResponse.redirect(new URL("/login?error=oauth-not-configured", request.url))

  const state = randomBytes(24).toString("hex")
  ;(await cookies()).set(STATE_COOKIE, state, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 10 * 60,
    path: "/",
  })

  const callback = new URL("/api/auth/callback", request.url)
  const authorize = new URL("https://github.com/login/oauth/authorize")
  authorize.searchParams.set("client_id", clientId)
  authorize.searchParams.set("redirect_uri", callback.toString())
  authorize.searchParams.set("scope", "read:user")
  authorize.searchParams.set("state", state)
  return NextResponse.redirect(authorize)
}
