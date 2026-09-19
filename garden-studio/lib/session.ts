import { cookies } from "next/headers"
import { SignJWT, jwtVerify } from "jose"

const SESSION_COOKIE = "garden-studio-session"
const SESSION_AGE_SECONDS = 60 * 60 * 12

export type StudioSession = {
  login: string
  name: string
  avatarUrl?: string
  mode: "github" | "preview"
}

function secret() {
  const value = process.env.GARDEN_STUDIO_SESSION_SECRET
  if (!value || value.length < 32) return null
  return new TextEncoder().encode(value)
}

export async function createSessionToken(session: StudioSession) {
  const key = secret()
  if (!key) throw new Error("GARDEN_STUDIO_SESSION_SECRET must contain at least 32 characters")
  return new SignJWT(session)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${SESSION_AGE_SECONDS}s`)
    .sign(key)
}

export async function readSession(): Promise<StudioSession | null> {
  const cookieStore = await cookies()
  const key = secret()
  if (!key) return null
  const token = cookieStore.get(SESSION_COOKIE)?.value
  if (!token) return null
  try {
    const verified = await jwtVerify(token, key, { algorithms: ["HS256"] })
    return verified.payload as StudioSession
  } catch {
    return null
  }
}

export async function setSession(session: StudioSession) {
  const token = await createSessionToken(session)
  ;(await cookies()).set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_AGE_SECONDS,
  })
}

export async function clearSession() {
  ;(await cookies()).set(SESSION_COOKIE, "", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  })
}

export function authConfigured() {
  return Boolean(
    secret() && process.env.GITHUB_OAUTH_CLIENT_ID && process.env.GITHUB_OAUTH_CLIENT_SECRET,
  )
}
