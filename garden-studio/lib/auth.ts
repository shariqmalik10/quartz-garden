import "server-only"

import { redirect } from "next/navigation"

import { readSession } from "./session"

export async function requireSession() {
  const session = await readSession()
  if (!session) redirect("/login")
  return session
}

export function allowedLogin() {
  return (process.env.GARDEN_STUDIO_ALLOWED_LOGIN || "shariqmalik10").toLowerCase()
}
