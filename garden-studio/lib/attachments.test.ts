import assert from "node:assert/strict"
import { describe, it } from "node:test"

import {
  attachmentPath,
  attachmentPathFromWikilink,
  detectAttachmentMime,
  safeAttachmentName,
  validateAttachment,
} from "./attachments"

describe("Garden Studio capture attachments", () => {
  it("normalizes names and confines uploads to a capture folder", () => {
    assert.equal(safeAttachmentName("My Screenshot (Final).PNG"), "my-screenshot-final.png")
    assert.equal(
      attachmentPath(
        "Areas/Blogs/Captures/gd-example.md",
        "My Screenshot (Final).PNG",
        "20260919-1234",
      ),
      "Attachments/Captures/gd-example/20260919-1234-my-screenshot-final.png",
    )
    assert.equal(attachmentPath("Writing/example.md", "image.png", "one"), null)
  })

  it("detects and validates file signatures", () => {
    const png = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    assert.equal(detectAttachmentMime(png), "image/png")
    assert.equal(validateAttachment("garden.png", "image/png", png), null)
    assert.match(validateAttachment("garden.jpg", "image/jpeg", png) || "", /contents/)
  })

  it("reads only capture attachment wikilinks", () => {
    assert.equal(
      attachmentPathFromWikilink("![[Attachments/Captures/gd-one/image.png]]"),
      "Attachments/Captures/gd-one/image.png",
    )
    assert.equal(attachmentPathFromWikilink("[[Private/secret.png]]"), null)
    assert.equal(
      attachmentPathFromWikilink("[[Attachments/Captures/gd-one/../../secret.png]]"),
      null,
    )
  })
})
