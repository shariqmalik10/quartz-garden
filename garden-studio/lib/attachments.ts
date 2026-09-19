export const MAX_ATTACHMENT_BYTES = 8 * 1024 * 1024

const ATTACHMENT_PATH =
  /^Attachments\/Captures\/[a-z0-9][a-z0-9-]*\/[a-z0-9][a-z0-9.-]*\.(?:jpe?g|png|webp|gif|pdf)$/i

const MIME_EXTENSIONS = new Map([
  ["image/jpeg", new Set(["jpg", "jpeg"])],
  ["image/png", new Set(["png"])],
  ["image/webp", new Set(["webp"])],
  ["image/gif", new Set(["gif"])],
  ["application/pdf", new Set(["pdf"])],
])

export function safeAttachmentName(value: string) {
  const normalized = value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
  const dot = normalized.lastIndexOf(".")
  const extension = dot > 0 ? normalized.slice(dot + 1).replace(/[^a-z0-9]/g, "") : ""
  const stem = (dot > 0 ? normalized.slice(0, dot) : normalized)
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64)
  if (!stem || !extension) return ""
  return `${stem}.${extension}`
}

export function detectAttachmentMime(bytes: Uint8Array) {
  const starts = (...values: number[]) => values.every((value, index) => bytes[index] === value)
  if (starts(0xff, 0xd8, 0xff)) return "image/jpeg"
  if (starts(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) return "image/png"
  const firstSix = new TextDecoder().decode(bytes.slice(0, 6))
  if (firstSix === "GIF87a" || firstSix === "GIF89a") return "image/gif"
  if (
    new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
    new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP"
  )
    return "image/webp"
  if (new TextDecoder().decode(bytes.slice(0, 4)) === "%PDF") return "application/pdf"
  return null
}

export function validateAttachment(fileName: string, declaredType: string, bytes: Uint8Array) {
  if (bytes.length === 0) return "Choose a non-empty file."
  if (bytes.length > MAX_ATTACHMENT_BYTES) return "Keep each attachment under 8 MB."
  const safeName = safeAttachmentName(fileName)
  if (!safeName) return "Use a filename with a supported extension."
  const detectedType = detectAttachmentMime(bytes)
  if (!detectedType || !MIME_EXTENSIONS.has(detectedType))
    return "Use a JPEG, PNG, WebP, GIF, or PDF file."
  if (declaredType && declaredType !== detectedType)
    return "The file contents do not match its type."
  const extension = safeName.split(".").at(-1) || ""
  if (!MIME_EXTENSIONS.get(detectedType)?.has(extension))
    return "The file extension does not match its contents."
  return null
}

export function attachmentPath(entryPath: string, fileName: string, nonce: string) {
  const match = entryPath.match(/^Areas\/[^/]+\/Captures\/([a-z0-9][a-z0-9-]*)\.md$/i)
  const safeName = safeAttachmentName(fileName)
  const safeNonce = nonce.replace(/[^a-z0-9-]/gi, "").slice(0, 32)
  if (!match || !safeName || !safeNonce) return null
  return `Attachments/Captures/${match[1]}/${safeNonce}-${safeName}`
}

export function attachmentWikilink(filePath: string) {
  return `[[${filePath}]]`
}

export function isAttachmentPath(value: string) {
  return ATTACHMENT_PATH.test(value)
}

export function attachmentPathFromWikilink(value: string) {
  const match = value.match(/^!?\[\[([^\]|]+)(?:\|[^\]]+)?\]\]$/)
  return match && isAttachmentPath(match[1]) ? match[1] : null
}
