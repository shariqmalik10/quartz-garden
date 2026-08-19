import test, { describe } from "node:test"
import assert from "node:assert"
import { Element, Root } from "hast"
import { normalizeHeadingPermalinks } from "./index"

describe("normalizeHeadingPermalinks", () => {
  test("names generated heading links and makes them keyboard reachable", () => {
    const root: Root = {
      type: "root",
      children: [
        {
          type: "element",
          tagName: "h2",
          properties: { id: "quiet-garden" },
          children: [
            { type: "text", value: "A " },
            {
              type: "element",
              tagName: "em",
              properties: {},
              children: [{ type: "text", value: "quiet" }],
            },
            { type: "text", value: " garden" },
            {
              type: "element",
              tagName: "a",
              properties: {
                href: "#quiet-garden",
                role: "anchor",
                ariaHidden: "true",
                tabIndex: -1,
                "data-no-popover": true,
              },
              children: [
                {
                  type: "element",
                  tagName: "svg",
                  properties: {},
                  children: [],
                },
              ],
            },
          ],
        },
      ],
    }

    normalizeHeadingPermalinks(root)

    const heading = root.children[0] as Element
    const anchor = heading.children[3] as Element
    assert.equal(anchor.properties.ariaLabel, "Link to heading: A quiet garden")
    assert.equal(anchor.properties.tabIndex, 0)
    assert.equal(anchor.properties.ariaHidden, undefined)
    assert.equal(anchor.properties.role, undefined)
    assert.deepEqual(anchor.properties.className, ["heading-permalink"])
  })
})
