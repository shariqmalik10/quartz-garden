import { NextResponse } from "next/server"

const rateBuckets = new Map<string, { count: number; resetAt: number }>()

export class RequestPayloadError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: "request_invalid" | "request_too_large",
  ) {
    super(message)
  }
}

export function sameOrigin(request: Request) {
  const origin = request.headers.get("origin")
  if (!origin) return false
  try {
    return new URL(origin).origin === new URL(request.url).origin
  } catch {
    return false
  }
}

export function jsonError(message: string, status: number, code: string, details?: unknown) {
  return NextResponse.json({ ok: false, message, code, details }, { status })
}

function clientAddress(request: Request) {
  return (
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    request.headers.get("x-real-ip")?.trim() ||
    "unknown"
  ).slice(0, 96)
}

export function enforceRateLimit(
  request: Request,
  scope: string,
  actor: string,
  limit: number,
  windowMs = 60_000,
) {
  const now = Date.now()
  if (rateBuckets.size >= 2_000) {
    for (const [key, bucket] of rateBuckets) {
      if (bucket.resetAt <= now) rateBuckets.delete(key)
    }
    while (rateBuckets.size >= 2_000) {
      const oldest = rateBuckets.keys().next().value
      if (!oldest) break
      rateBuckets.delete(oldest)
    }
  }
  const key = `${scope}:${actor.slice(0, 96)}:${clientAddress(request)}`
  const existing = rateBuckets.get(key)
  if (!existing || existing.resetAt <= now) {
    rateBuckets.set(key, { count: 1, resetAt: now + windowMs })
    return null
  }
  if (existing.count >= limit) {
    const retryAfter = Math.max(1, Math.ceil((existing.resetAt - now) / 1_000))
    return NextResponse.json(
      {
        ok: false,
        message: "Too many requests. Wait a moment and try again.",
        code: "rate_limited",
      },
      { status: 429, headers: { "Retry-After": String(retryAfter) } },
    )
  }
  existing.count += 1
  return null
}

export function contentLengthExceeds(request: Request, maximumBytes: number) {
  const raw = request.headers.get("content-length")
  if (!raw) return false
  const length = Number(raw)
  return !Number.isFinite(length) || length < 0 || length > maximumBytes
}

export async function readJsonBody<T>(request: Request, maximumBytes = 256 * 1024) {
  if (contentLengthExceeds(request, maximumBytes)) {
    throw new RequestPayloadError(
      "The request is larger than this action allows.",
      413,
      "request_too_large",
    )
  }
  if (!request.body) {
    throw new RequestPayloadError("The request body is missing.", 400, "request_invalid")
  }
  const reader = request.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    total += value.byteLength
    if (total > maximumBytes) {
      await reader.cancel()
      throw new RequestPayloadError(
        "The request is larger than this action allows.",
        413,
        "request_too_large",
      )
    }
    chunks.push(value)
  }
  const bytes = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    bytes.set(chunk, offset)
    offset += chunk.byteLength
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes)) as T
  } catch {
    throw new RequestPayloadError("The request body is not valid JSON.", 400, "request_invalid")
  }
}

export function payloadError(error: unknown, fallback: string) {
  if (error instanceof RequestPayloadError) {
    return jsonError(error.message, error.status, error.code)
  }
  return jsonError(fallback, 400, "request_invalid")
}
