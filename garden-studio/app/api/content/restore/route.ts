import { revalidatePath } from "next/cache"
import { NextResponse } from "next/server"

import { pathAllowed } from "@/lib/content"
import { githubConfigured } from "@/lib/github"
import { readVaultFile, RepositoryConflictError, writeVaultFile } from "@/lib/github-write"
import { collectionForPath } from "@/lib/paths"
import { jsonError, sameOrigin } from "@/lib/request"
import { readSession } from "@/lib/session"

export async function POST(request: Request) {
  const session = await readSession()
  if (!session) return jsonError("Sign in again before restoring.", 401, "session_required")
  if (!sameOrigin(request))
    return jsonError("This restore request was not accepted.", 403, "origin_invalid")
  const payload = (await request.json()) as {
    path?: string
    targetRevision?: string
    expectedRevision?: string
  }
  const collection = collectionForPath(payload.path || "")
  if (!collection || !pathAllowed(payload.path || "", collection))
    return jsonError("That file is outside the managed vault paths.", 400, "path_unsafe")
  if (!payload.targetRevision || !/^[a-f0-9]{40}$/i.test(payload.targetRevision))
    return jsonError("Choose a valid revision.", 400, "revision_invalid")

  if (session.mode === "preview" || process.env.GARDEN_STUDIO_DEMO === "true") {
    return NextResponse.json({
      ok: true,
      demo: true,
      message: "Restore simulated in preview mode.",
    })
  }
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")
  const previous = await readVaultFile(payload.path!, payload.targetRevision)
  if (!previous)
    return jsonError("That historical version no longer exists.", 404, "revision_missing")
  try {
    const result = await writeVaultFile({
      filePath: payload.path!,
      content: previous.content,
      expectedRevision: payload.expectedRevision,
      message: `Restore ${payload.path} from ${payload.targetRevision.slice(0, 7)}`,
    })
    revalidatePath("/", "layout")
    return NextResponse.json({ ok: true, ...result, message: "Restored as a new vault commit." })
  } catch (error) {
    if (error instanceof RepositoryConflictError)
      return jsonError(error.message, 409, "edit_conflict")
    return jsonError(
      error instanceof Error ? error.message : "Restore failed.",
      502,
      "restore_failed",
    )
  }
}
