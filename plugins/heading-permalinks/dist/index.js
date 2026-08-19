function isHeading(tagName) {
  return /^h[1-6]$/.test(tagName)
}

function elementText(node) {
  if (node.type === "text") return node.value
  if (node.type !== "element") return ""
  if (node.properties?.["data-no-popover"]) return ""
  return node.children.map(elementText).join("")
}

function normalizeHeadingPermalinks(root) {
  function walk(node) {
    for (const child of node.children) {
      if (child.type !== "element") continue

      if (isHeading(child.tagName) && child.properties?.id) {
        const anchor = child.children.find(
          (candidate) =>
            candidate.type === "element" &&
            candidate.tagName === "a" &&
            Boolean(candidate.properties?.["data-no-popover"]),
        )

        if (anchor) {
          const headingText = child.children.map(elementText).join("").replace(/\s+/g, " ").trim()
          const className = anchor.properties.className
          const classes = Array.isArray(className)
            ? className.filter((value) => typeof value === "string")
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

const HeadingPermalinks = () => ({
  name: "HeadingPermalinks",
  htmlPlugins() {
    return [
      () => (tree) => {
        normalizeHeadingPermalinks(tree)
      },
    ]
  },
})

export { HeadingPermalinks, normalizeHeadingPermalinks }
export default HeadingPermalinks
