import { revalidatePath } from "next/cache"
import { NextResponse } from "next/server"

import { readSession } from "@/lib/session"
import {
  pathAllowed,
  pathForFields,
  serializeFields,
  validateFields,
  type EditorFields,
} from "@/lib/content"
import { githubConfigured } from "@/lib/github"
import { readVaultFile, RepositoryConflictError, writeVaultFile } from "@/lib/github-write"
import { jsonError, sameOrigin } from "@/lib/request"
import { getVaultSnapshot } from "@/lib/vault"

type SaveRequest = {
  fields: EditorFields
  originalPath?: string
  expectedRevision?: string
  intent?: "draft" | "ready"
}

export async function POST(request: Request) {
  const session = await readSession()
  if (!session) return jsonError("Sign in again before saving.", 401, "session_required")
  if (!sameOrigin(request))
    return jsonError("This save request was not accepted.", 403, "origin_invalid")

  let payload: SaveRequest
  try {
    payload = (await request.json()) as SaveRequest
  } catch {
    return jsonError("The editor sent an unreadable request.", 400, "request_invalid")
  }
  if (!payload.fields || !["writing", "quotes", "links"].includes(payload.fields.collection)) {
    return jsonError("Choose a managed collection.", 400, "collection_invalid")
  }

  const fields = structuredClone(payload.fields)
  if (payload.intent === "ready") {
    if (fields.collection === "writing") {
      fields.visibility = "public"
      fields.draft = false
    } else if (fields.collection === "quotes") {
      fields.publish = true
    }
  }
  const issues = validateFields(fields)
  if (issues.length)
    return jsonError("Fix the highlighted fields before saving.", 422, "schema_invalid", issues)

  const filePath = payload.originalPath || pathForFields(fields)
  if (!filePath || !pathAllowed(filePath, fields.collection)) {
    return jsonError("The requested vault path is outside this collection.", 400, "path_unsafe")
  }
  if (fields.collection === "links") {
    const snapshot = await getVaultSnapshot()
    if (!snapshot.areas.some((area) => area.name === fields.area)) {
      return jsonError("Choose an existing Obsidian area.", 422, "area_unknown")
    }
  }

  const content = serializeFields(fields, filePath)
  if (process.env.GARDEN_STUDIO_DEMO === "true" || session.mode === "preview") {
    return NextResponse.json({
      ok: true,
      demo: true,
      path: filePath,
      revision: `demo-${Date.now()}`,
      message: "Saved in this browser’s preview workspace.",
    })
  }
  if (process.env.GARDEN_STUDIO_LOCAL_VAULT) {
    return jsonError(
      "Local-vault mode is read-only. Save through Obsidian or connect the GitHub App.",
      409,
      "local_readonly",
    )
  }
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")

  if (!payload.originalPath && (await readVaultFile(filePath))) {
    return jsonError("An entry already uses this path. Choose another slug.", 409, "path_exists")
  }
  try {
    const result = await writeVaultFile({
      filePath,
      content,
      expectedRevision: payload.expectedRevision,
      message: `${payload.originalPath ? "Update" : "Create"} ${fields.collection}: ${(fields.title || fields.quote).slice(0, 72)}`,
    })
    revalidatePath("/", "layout")
    return NextResponse.json({
      ok: true,
      path: filePath,
      ...result,
      message: "Saved to the private vault.",
    })
  } catch (error) {
    if (error instanceof RepositoryConflictError) {
      const latest = await readVaultFile(filePath)
      return jsonError(error.message, 409, "edit_conflict", latest)
    }
    return jsonError(
      error instanceof Error ? error.message : "The vault write failed.",
      502,
      "save_failed",
    )
  }
}
