import { timingSafeEqual } from "node:crypto"
import { NextResponse } from "next/server"

import { setSession } from "@/lib/session"

function matches(left: string, right: string) {
  const a = Buffer.from(left)
  const b = Buffer.from(right)
  return a.length === b.length && timingSafeEqual(a, b)
}

export async function POST(request: Request) {
  const enabled = process.env.GARDEN_STUDIO_DEMO === "true" || process.env.VERCEL_ENV === "preview"
  const expected = process.env.GARDEN_STUDIO_PREVIEW_KEY || ""
  const form = await request.formData()
  const supplied = String(form.get("key") || "")
  if (!enabled || !expected || !matches(supplied, expected)) {
    return NextResponse.redirect(new URL("/login?error=preview-denied", request.url), 303)
  }
  await setSession({ login: "preview", name: "Studio preview", mode: "preview" })
  return NextResponse.redirect(new URL("/", request.url), 303)
}
