import { NextResponse } from "next/server"

import {
  attachmentPath,
  attachmentWikilink,
  detectAttachmentMime,
  MAX_ATTACHMENT_BYTES,
  validateAttachment,
} from "@/lib/attachments"
import { githubConfigured } from "@/lib/github"
import { writeVaultBinary } from "@/lib/github-binary"
import { contentLengthExceeds, enforceRateLimit, jsonError, sameOrigin } from "@/lib/request"
import { readSession } from "@/lib/session"

const MAX_MULTIPART_BYTES = MAX_ATTACHMENT_BYTES + 512 * 1024

export async function POST(request: Request) {
  const session = await readSession()
  if (!session) return jsonError("Sign in again before uploading.", 401, "session_required")
  if (!sameOrigin(request))
    return jsonError("This upload request was not accepted.", 403, "origin_invalid")
  const limited = enforceRateLimit(request, "upload", session.login, 20)
  if (limited) return limited
  if (contentLengthExceeds(request, MAX_MULTIPART_BYTES)) {
    return jsonError("Keep each attachment under 8 MB.", 413, "request_too_large")
  }

  let form: FormData
  try {
    form = await request.formData()
  } catch {
    return jsonError("The upload could not be read.", 400, "request_invalid")
  }
  const file = form.get("file")
  const entryPath = form.get("entryPath")
  if (!(file instanceof File) || typeof entryPath !== "string")
    return jsonError("Choose a file and a saved link entry.", 400, "upload_incomplete")
  if (file.size > MAX_ATTACHMENT_BYTES)
    return jsonError("Keep each attachment under 8 MB.", 413, "request_too_large")

  const bytes = new Uint8Array(await file.arrayBuffer())
  const issue = validateAttachment(file.name, file.type, bytes)
  if (issue) return jsonError(issue, 422, "attachment_invalid")
  const nonce = `${Date.now().toString(36)}-${crypto.randomUUID().slice(0, 6)}`
  const filePath = attachmentPath(entryPath, file.name, nonce)
  if (!filePath)
    return jsonError(
      "Attachments can only be added to a saved-link capture after its first save.",
      400,
      "path_unsafe",
    )

  const mime = detectAttachmentMime(bytes)
  if (session.mode === "preview" || process.env.GARDEN_STUDIO_DEMO === "true") {
    return NextResponse.json({
      ok: true,
      demo: true,
      path: filePath,
      wikilink: attachmentWikilink(filePath),
      mime,
      message: "Attachment staged in the browser preview.",
    })
  }
  if (process.env.GARDEN_STUDIO_LOCAL_VAULT)
    return jsonError(
      "Local-vault mode is read-only. Add the attachment in Obsidian or connect the GitHub App.",
      409,
      "local_readonly",
    )
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")

  try {
    await writeVaultBinary(filePath, bytes)
    return NextResponse.json({
      ok: true,
      path: filePath,
      wikilink: attachmentWikilink(filePath),
      mime,
      message: "Attachment saved to the private vault. Save the entry to keep its reference.",
    })
  } catch (error) {
    console.error("Garden Studio attachment upload failed", error)
    return jsonError("The attachment could not be saved.", 502, "upload_failed")
  }
}
