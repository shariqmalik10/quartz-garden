import assert from "node:assert/strict"
import { describe, it } from "node:test"

import YAML from "yaml"

import {
  emptyFields,
  parseEditorFields,
  pathAllowed,
  pathForFields,
  serializeFields,
  slugify,
  validateFields,
} from "./content"

function frontmatter(markdown: string) {
  const match = markdown.match(/^---\n([\s\S]*?)\n---/)
  assert.ok(match)
  return YAML.parse(match[1]) as Record<string, unknown>
}

describe("Garden Studio content editor contracts", () => {
  it("creates stable Obsidian-compatible writing paths", () => {
    const fields = { ...emptyFields("writing"), title: "A Small & Durable Web", slug: "" }
    assert.equal(slugify(fields.title), "a-small-durable-web")
    assert.equal(pathForFields(fields), "Writing/Blogs/a-small-durable-web.md")
  })

  it("serializes a writing draft using contract v1", () => {
    const fields = {
      ...emptyFields("writing"),
      title: "Field Notes",
      slug: "field-notes",
      body: "A paragraph with an [[Obsidian Link]].",
      tags: ["notes", " garden "],
    }
    const output = serializeFields(fields)
    assert.deepEqual(frontmatter(output), {
      contract_version: 1,
      kind: "writing",
      title: "Field Notes",
      slug: "field-notes",
      date: fields.date,
      visibility: "private",
      draft: true,
      tags: ["notes", "garden"],
    })
    assert.match(output, /\[\[Obsidian Link\]\]/)
  })

  it("parses complete editor payloads and rejects malformed values", () => {
    const fields = emptyFields("writing")
    assert.deepEqual(parseEditorFields(fields), fields)
    assert.equal(parseEditorFields({ ...fields, body: 42 }), null)
    const legacy = { ...fields } as Record<string, unknown>
    delete legacy.attachments
    assert.deepEqual(parseEditorFields(legacy)?.attachments, [])
  })

  it("rejects unsafe paths and non-http saved links", () => {
    assert.equal(pathAllowed("../Private/secret.md", "writing"), false)
    assert.equal(pathAllowed("Areas/Blogs/Captures/gd-one.md", "links"), true)
    const fields = {
      ...emptyFields("links"),
      title: "Bad link",
      slug: "bad-link",
      sourceUrl: "javascript:alert(1)",
    }
    assert.ok(validateFields(fields).some((issue) => issue.field === "sourceUrl"))
    fields.sourceUrl = "https://example.com"
    fields.attachments = ["[[Attachments/Captures/gd-one/../../secret.png]]"]
    assert.ok(validateFields(fields).some((issue) => issue.field === "attachments"))
  })
})
