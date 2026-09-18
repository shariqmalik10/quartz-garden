import test, { describe } from "node:test"
import assert from "node:assert"
import { KimiThoughts } from "./components/index"

type VNode = { props?: Record<string, unknown> }

function countOpenButtons(node: unknown): number {
  if (!node || typeof node !== "object") return 0
  const vnode = node as VNode
  let count = vnode.props?.["data-kt-open"] === "true" ? 1 : 0
  const children = vnode.props?.children
  if (Array.isArray(children)) {
    for (const child of children) count += countOpenButtons(child)
  } else if (children) {
    count += countOpenButtons(children)
  }
  return count
}

describe("KimiThoughts", () => {
  test("only renders the sketchbook on its own route", () => {
    const component = KimiThoughts()

    assert.equal(component({ fileData: { slug: "index" } }), null)
    assert.equal(component({ fileData: { slug: "notes/some-note" } }), null)
    assert.equal(component({ fileData: { slug: "model-sketchbooks/deepseek" } }), null)

    const vnode = component({ fileData: { slug: "model-sketchbooks/kimi" } }) as {
      type: string
      props: Record<string, unknown>
    }
    assert.ok(vnode, "expected the sketchbook to render on /model-sketchbooks/kimi")
    assert.equal(vnode.type, "section")
    assert.equal(vnode.props["data-kt-lab"], "true")
  })

  test("gives every picture a way into the focus view", () => {
    const component = KimiThoughts()
    const vnode = component({ fileData: { slug: "model-sketchbooks/kimi" } })
    assert.equal(countOpenButtons(vnode), 8)
  })

  test("ships a doodle script that parses and draws with the canvas API", () => {
    const script = KimiThoughts().afterDOMLoaded
    assert.equal(typeof script, "string")

    // parse only: throws on syntax errors, never executes
    new Function(script as string)

    for (const token of [
      "setupKimiThoughts",
      "requestAnimationFrame",
      'getContext("2d")',
      "toBlob",
      "buildFocusDialog",
      "kt-focus",
      "dashline",
      "startIdle",
    ]) {
      assert.ok((script as string).includes(token), `missing ${token} in the doodle script`)
    }
  })
})
