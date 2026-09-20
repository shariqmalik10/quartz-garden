import { NextResponse } from "next/server"

import { githubConfigured } from "@/lib/github"
import { dispatchPublication } from "@/lib/publication"
import { enforceRateLimit, jsonError, sameOrigin } from "@/lib/request"
import { readSession } from "@/lib/session"

export async function POST(request: Request) {
  const session = await readSession()
  if (!session)
    return jsonError("Sign in again before creating a preview.", 401, "session_required")
  if (!sameOrigin(request))
    return jsonError("This preview request was not accepted.", 403, "origin_invalid")
  const limited = enforceRateLimit(request, "preview", session.login, 5)
  if (limited) return limited
  if (session.mode === "preview" || process.env.GARDEN_STUDIO_DEMO === "true") {
    return NextResponse.json({
      ok: true,
      demo: true,
      dispatchedAt: new Date().toISOString(),
      message: "Synthetic preview started.",
    })
  }
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")
  try {
    return NextResponse.json({
      ok: true,
      ...(await dispatchPublication()),
      message: "Preview requested from the private vault.",
    })
  } catch (error) {
    console.error("Garden Studio preview dispatch failed", error)
    return jsonError("The preview could not be started.", 502, "dispatch_failed")
  }
}
