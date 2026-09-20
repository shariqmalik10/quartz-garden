import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { enforceRateLimit, readJsonBody, RequestPayloadError, sameOrigin } from "./request"

describe("Garden Studio request boundaries", () => {
  it("accepts only the exact request origin", () => {
    const accepted = new Request("https://studio.example/api/save", {
      headers: { origin: "https://studio.example" },
    })
    const rejected = new Request("https://studio.example/api/save", {
      headers: { origin: "https://attacker.example" },
    })
    assert.equal(sameOrigin(accepted), true)
    assert.equal(sameOrigin(rejected), false)
  })

  it("limits a repeated actor and address within one window", () => {
    const request = new Request("https://studio.example/api/save", {
      headers: { "x-forwarded-for": "203.0.113.9" },
    })
    const scope = `test-${Date.now()}-${Math.random()}`
    assert.equal(enforceRateLimit(request, scope, "gardener", 2), null)
    assert.equal(enforceRateLimit(request, scope, "gardener", 2), null)
    const response = enforceRateLimit(request, scope, "gardener", 2)
    assert.equal(response?.status, 429)
    assert.ok(response?.headers.get("retry-after"))
  })

  it("reads bounded JSON and rejects oversized bodies", async () => {
    const payload = await readJsonBody<{ title: string }>(
      new Request("https://studio.example/api/save", {
        method: "POST",
        body: JSON.stringify({ title: "Garden note" }),
      }),
      128,
    )
    assert.equal(payload.title, "Garden note")

    await assert.rejects(
      readJsonBody(
        new Request("https://studio.example/api/save", {
          method: "POST",
          body: JSON.stringify({ body: "x".repeat(256) }),
        }),
        64,
      ),
      (error: unknown) =>
        error instanceof RequestPayloadError && error.code === "request_too_large",
    )
  })
})
