import test, { describe } from "node:test"
import assert from "node:assert"
import { DeepSeekThoughts } from "./components/index"

describe("DeepSeekThoughts", () => {
  test("only renders the sketchbook on its own route", () => {
    const component = DeepSeekThoughts()

    assert.equal(component({ fileData: { slug: "index" } }), null)
    assert.equal(component({ fileData: { slug: "notes/some-note" } }), null)

    const vnode = component({ fileData: { slug: "deepseek-thoughts" } }) as {
      type: string
      props: Record<string, unknown>
    }
    assert.ok(vnode, "expected the sketchbook to render on /deepseek-thoughts")
    assert.equal(vnode.type, "section")
    assert.equal(vnode.props["data-ds-lab"], "true")
  })

  test("ships a doodle script that parses and draws with the canvas API", () => {
    const script = DeepSeekThoughts().afterDOMLoaded
    assert.equal(typeof script, "string")

    // parse only: throws on syntax errors, never executes
    new Function(script as string)

    for (const token of [
      "setupDeepSeekThoughts",
      "requestAnimationFrame",
      'getContext("2d")',
      "toBlob",
    ]) {
      assert.ok((script as string).includes(token), `missing ${token} in the doodle script`)
    }
  })
})
