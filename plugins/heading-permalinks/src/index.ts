import type { Element, ElementContent, Root } from "hast"
import type { QuartzTransformerPlugin } from "@quartz-community/types"

function isHeading(tagName: string): boolean {
  return /^h[1-6]$/.test(tagName)
}

function elementText(node: ElementContent): string {
  if (node.type === "text") return node.value
  if (node.type !== "element") return ""
  if (node.properties?.["data-no-popover"]) return ""
  return node.children.map(elementText).join("")
}

/**
 * Normalize the icon-only link emitted by Quartz's GFM heading transformer.
 * The transform runs after GFM, so the upstream transformer remains untouched.
 */
export function normalizeHeadingPermalinks(root: Root): void {
  function walk(node: Root | Element): void {
    for (const child of node.children) {
      if (child.type !== "element") continue

      if (isHeading(child.tagName) && child.properties?.id) {
        const anchor = child.children.find(
          (candidate): candidate is Element =>
            candidate.type === "element" &&
            candidate.tagName === "a" &&
            Boolean(candidate.properties?.["data-no-popover"]),
        )

        if (anchor) {
          const headingText = child.children.map(elementText).join("").replace(/\s+/g, " ").trim()
          const className = anchor.properties.className
          const classes = Array.isArray(className)
            ? className.filter((value): value is string => typeof value === "string")
            : []

          anchor.properties = {
            ...anchor.properties,
            className: [...new Set([...classes, "heading-permalink"])],
            ariaLabel: headingText ? `Link to heading: ${headingText}` : "Link to heading",
            tabIndex: 0,
          }
          delete anchor.properties.ariaHidden
          delete anchor.properties.role
        }
      }

      walk(child)
    }
  }

  walk(root)
}

export const HeadingPermalinks: QuartzTransformerPlugin = () => ({
  name: "HeadingPermalinks",
  htmlPlugins() {
    return [
      () => (tree: Root) => {
        normalizeHeadingPermalinks(tree)
      },
    ]
  },
})

export default HeadingPermalinks
