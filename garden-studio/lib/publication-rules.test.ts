import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { pullMatchesPreview, summarizeChecks } from "./publication-rules"

describe("publication safety rules", () => {
  it("requires at least one completed passing check", () => {
    assert.deepEqual(summarizeChecks([]), { ready: false, pending: true, failed: false })
    assert.deepEqual(
      summarizeChecks([{ name: "Quartz", status: "completed", conclusion: "success" }]),
      { ready: true, pending: false, failed: false },
    )
  })

  it("keeps a failed or pending preview from becoming ready", () => {
    assert.deepEqual(
      summarizeChecks([{ name: "Vercel", status: "in_progress", conclusion: null }]),
      { ready: false, pending: true, failed: false },
    )
    assert.deepEqual(
      summarizeChecks([{ name: "Quartz", status: "completed", conclusion: "failure" }]),
      { ready: false, pending: false, failed: true },
    )
  })

  it("only accepts the exact open preview pull request", () => {
    const pull = {
      state: "open",
      head: { ref: "studio/garden-preview", sha: "abc123" },
      base: { ref: "main" },
    }
    assert.equal(pullMatchesPreview(pull, "studio/garden-preview", "abc123"), true)
    assert.equal(pullMatchesPreview(pull, "studio/garden-preview", "different"), false)
    assert.equal(
      pullMatchesPreview({ ...pull, state: "closed" }, "studio/garden-preview", "abc123"),
      false,
    )
  })
})
