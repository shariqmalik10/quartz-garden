import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { emptyFields } from "./content"
import {
  applyMarkdownCommand,
  documentStats,
  fieldsWithTemplate,
  MARKDOWN_COMMANDS,
} from "./editor-tools"

describe("Garden Studio authoring tools", () => {
  it("wraps the current selection and preserves a useful selection", () => {
    const command = MARKDOWN_COMMANDS.find((item) => item.id === "bold")
    assert.ok(command)
    assert.deepEqual(applyMarkdownCommand("hello garden", 6, 12, command), {
      body: "hello **garden**",
      selectionStart: 8,
      selectionEnd: 14,
    })
  })

  it("uses placeholders when no text is selected", () => {
    const command = MARKDOWN_COMMANDS.find((item) => item.id === "wikilink")
    assert.ok(command)
    assert.equal(applyMarkdownCommand("", 0, 0, command).body, "[[Note title]]")
  })

  it("applies writing templates without removing existing tags", () => {
    const fields = { ...emptyFields("writing"), tags: ["personal"] }
    const next = fieldsWithTemplate(fields, "build-log")
    assert.match(next.body, /## Decisions/)
    assert.deepEqual(next.tags, ["personal", "building", "project-log"])
  })

  it("calculates compact document statistics", () => {
    assert.deepEqual(documentStats("one two three"), {
      words: 3,
      characters: 13,
      readingMinutes: 1,
    })
  })
})
