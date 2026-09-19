import { NextResponse } from "next/server"

import { githubConfigured } from "@/lib/github"
import { mergePublication } from "@/lib/publication"
import { jsonError, sameOrigin } from "@/lib/request"
import { readSession } from "@/lib/session"

export async function POST(request: Request) {
  const session = await readSession()
  if (!session) return jsonError("Sign in again before publishing.", 401, "session_required")
  if (!sameOrigin(request))
    return jsonError("This publish request was not accepted.", 403, "origin_invalid")
  const payload = (await request.json()) as { pullRequest?: number; confirmation?: string }
  if (!Number.isInteger(payload.pullRequest) || payload.confirmation !== "publish") {
    return jsonError("Type publish to confirm the merge.", 400, "confirmation_required")
  }
  if (session.mode === "preview" || process.env.GARDEN_STUDIO_DEMO === "true") {
    return jsonError("Demo mode never merges a pull request.", 409, "demo_readonly")
  }
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")
  try {
    const result = await mergePublication(payload.pullRequest!)
    if (!result.merged)
      return jsonError(result.message || "GitHub did not merge the preview.", 409, "merge_rejected")
    return NextResponse.json({ ok: true, ...result, message: "Published to the public garden." })
  } catch (error) {
    return jsonError(
      error instanceof Error ? error.message : "Publish failed.",
      409,
      "merge_failed",
    )
  }
}
