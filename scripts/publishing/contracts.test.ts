import assert from "node:assert/strict"
import test from "node:test"

import {
  CONTRACT_VERSION,
  ContentContractError,
  safeRelativePath,
  validateDocument,
} from "./contracts.mjs"

test("validates a version-one writing contract", () => {
  assert.doesNotThrow(() =>
    validateDocument(
      "writing",
      {
        kind: "writing",
        title: "A useful note",
        date: "2026-09-19",
        visibility: "public",
        draft: false,
      },
      "Writing/a-useful-note.md",
    ),
  )
  assert.equal(CONTRACT_VERSION, 1)
})

test("returns stable machine-readable validation details", () => {
  assert.throws(
    () => validateDocument("quote", { kind: "quote", quote: "" }, "Quotes/empty.md"),
    (error: unknown) => {
      assert.ok(error instanceof ContentContractError)
      assert.equal(error.code, "schema_invalid")
      assert.deepEqual(
        error.details.map(({ field }) => field),
        ["quote", "publish"],
      )
      return true
    },
  )
})

test("rejects unsafe site paths", () => {
  assert.throws(
    () => safeRelativePath("../private", "Areas/Test/Test.md", "area", "site_slug"),
    /must be a safe relative path/,
  )
})
