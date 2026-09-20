import { NextResponse } from "next/server"

import { githubConfigured } from "@/lib/github"
import { previewBranch, publicationStatus } from "@/lib/publication"
import { enforceRateLimit, jsonError } from "@/lib/request"
import { readSession } from "@/lib/session"

export async function GET(request: Request) {
  const session = await readSession()
  if (!session)
    return jsonError("Sign in again to see publication status.", 401, "session_required")
  const limited = enforceRateLimit(request, "publication-status", session.login, 120)
  if (limited) return limited
  const since = new URL(request.url).searchParams.get("since") || undefined
  if (session.mode === "preview" || process.env.GARDEN_STUDIO_DEMO === "true") {
    return NextResponse.json({
      phase: since ? "ready" : "idle",
      branch: previewBranch(),
      commit: since ? "demo000" : undefined,
      pullRequest: since
        ? {
            number: 6,
            url: "https://github.com/shariqmalik10/quartz-garden/pull/6",
            state: "open",
            merged: false,
          }
        : undefined,
      checks: since
        ? [{ name: "Garden Studio demo", status: "completed", conclusion: "success" }]
        : [],
      previewUrl: since
        ? "https://shariq-quartz-garden-git-codex-garden-studio-shariq-s-projects.vercel.app"
        : undefined,
      message: since
        ? "Synthetic preview is ready for interface review. Merge stays disabled in demo mode."
        : "No preview run has started yet.",
    })
  }
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")
  try {
    return NextResponse.json(await publicationStatus(since))
  } catch (error) {
    console.error("Garden Studio publication status failed", error)
    return jsonError("Publication status is temporarily unavailable.", 502, "status_failed")
  }
}
