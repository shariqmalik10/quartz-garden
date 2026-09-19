import { NextResponse } from "next/server"

export function sameOrigin(request: Request) {
  const origin = request.headers.get("origin")
  if (!origin) return false
  try {
    return new URL(origin).origin === new URL(request.url).origin
  } catch {
    return false
  }
}

export function jsonError(message: string, status: number, code: string, details?: unknown) {
  return NextResponse.json({ ok: false, message, code, details }, { status })
}
