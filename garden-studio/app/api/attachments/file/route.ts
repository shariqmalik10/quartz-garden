import { detectAttachmentMime, isAttachmentPath } from "@/lib/attachments"
import { readVaultBinary } from "@/lib/github-binary"
import { githubConfigured } from "@/lib/github"
import { jsonError } from "@/lib/request"
import { readSession } from "@/lib/session"

export async function GET(request: Request) {
  const session = await readSession()
  if (!session) return jsonError("Sign in to view this attachment.", 401, "session_required")
  const filePath = new URL(request.url).searchParams.get("path") || ""
  if (!isAttachmentPath(filePath))
    return jsonError("That attachment path is not allowed.", 400, "path_unsafe")
  if (session.mode === "preview" || process.env.GARDEN_STUDIO_DEMO === "true")
    return jsonError("Synthetic uploads do not contain private media.", 404, "demo_media")
  if (!githubConfigured())
    return jsonError("The GitHub App is not configured.", 503, "github_unavailable")
  try {
    const bytes = await readVaultBinary(filePath)
    if (!bytes) return jsonError("Attachment not found.", 404, "attachment_missing")
    const mime = detectAttachmentMime(bytes)
    if (!mime) return jsonError("Unsupported attachment type.", 415, "attachment_invalid")
    return new Response(Buffer.from(bytes), {
      headers: {
        "Content-Type": mime,
        "Content-Disposition": `inline; filename="${filePath.split("/").at(-1)}"`,
        "Cache-Control": "private, max-age=60",
        "X-Content-Type-Options": "nosniff",
      },
    })
  } catch (error) {
    return jsonError(
      error instanceof Error ? error.message : "The attachment could not be loaded.",
      502,
      "attachment_failed",
    )
  }
}
