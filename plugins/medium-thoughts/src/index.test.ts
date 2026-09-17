import test, { describe } from "node:test"
import assert from "node:assert"
import { MediumThoughts } from "./components/index"

type VNode = { props?: Record<string, unknown> }

function countOpenButtons(node: unknown): number {
  if (!node || typeof node !== "object") return 0
  const vnode = node as VNode
  let count = vnode.props?.["data-mt-open"] === "true" ? 1 : 0
  const children = vnode.props?.children
  if (Array.isArray(children)) {
    for (const child of children) count += countOpenButtons(child)
  } else if (children) {
    count += countOpenButtons(children)
  }
  return count
}

describe("MediumThoughts", () => {
  test("only renders the sketchbook on its own route", () => {
    const component = MediumThoughts()

    assert.equal(component({ fileData: { slug: "index" } }), null)
    assert.equal(component({ fileData: { slug: "notes/some-note" } }), null)

    const vnode = component({ fileData: { slug: "model-sketchbooks/5-6-medium" } }) as {
      type: string
      props: Record<string, unknown>
    }
    assert.ok(vnode, "expected the sketchbook to render on /model-sketchbooks/5-6-medium")
    assert.equal(vnode.type, "section")
    assert.equal(vnode.props["data-mt-lab"], "true")
  })

  test("gives every picture a way into the focus view", () => {
    const component = MediumThoughts()
    const vnode = component({ fileData: { slug: "model-sketchbooks/5-6-medium" } })
    assert.equal(countOpenButtons(vnode), 6)
  })

  test("ships a doodle script that parses and draws with the canvas API", () => {
    const script = MediumThoughts().afterDOMLoaded
    assert.equal(typeof script, "string")

    // parse only: throws on syntax errors, never executes
    new Function(script as string)

    for (const token of [
      "setupMediumThoughts",
      "requestAnimationFrame",
      'getContext("2d")',
      "toBlob",
      "buildFocusDialog",
      "data-mt-focus",
    ]) {
      assert.ok((script as string).includes(token), `missing ${token} in the doodle script`)
    }
  })
})
