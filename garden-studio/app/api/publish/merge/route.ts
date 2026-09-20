import { NextResponse } from "next/server"

import { githubConfigured } from "@/lib/github"
import { mergePublication } from "@/lib/publication"
import { enforceRateLimit, jsonError, payloadError, readJsonBody, sameOrigin } from "@/lib/request"
import { readSession } from "@/lib/session"

type MergeRequest = { pullRequest?: number; confirmation?: string }

export async function POST(request: Request) {
  const session = await readSession()
  if (!session) return jsonError("Sign in again before publishing.", 401, "session_required")
  if (!sameOrigin(request))
    return jsonError("This publish request was not accepted.", 403, "origin_invalid")
  const limited = enforceRateLimit(request, "merge", session.login, 5)
  if (limited) return limited

  let payload: MergeRequest
  try {
    payload = await readJsonBody<MergeRequest>(request, 8 * 1024)
  } catch (error) {
    return payloadError(error, "The publish request could not be read.")
  }
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
      return jsonError("GitHub did not merge the reviewed preview.", 409, "merge_rejected")
    return NextResponse.json({ ok: true, ...result, message: "Published to the public garden." })
  } catch (error) {
    console.error("Garden Studio publication merge failed", error)
    return jsonError("The reviewed preview could not be merged.", 409, "merge_failed")
  }
}
