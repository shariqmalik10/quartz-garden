import { h } from "preact"

const entryDate = (page) =>
  page.dates?.published ?? page.dates?.created ?? page.dates?.modified ?? null

const isPublicWriting = (page) => {
  if (!page.slug?.startsWith("notes/") || page.slug === "notes/index") return false
  const frontmatter = page.frontmatter ?? {}
  return frontmatter.draft !== true && frontmatter.visibility !== "private"
}

export const WritingList = (userOptions = {}) => {
  const options = { limit: 5, linkToMore: "/notes", ...userOptions }

  const WritingListComponent = ({ allFiles, fileData }) => {
    if (fileData.slug !== "index") return null

    const entries = allFiles
      .filter(isPublicWriting)
      .map((page) => ({ page, date: entryDate(page) }))
      .sort((left, right) => {
        const dateDifference = (right.date?.getTime?.() ?? 0) - (left.date?.getTime?.() ?? 0)
        if (dateDifference !== 0) return dateDifference
        return String(left.page.frontmatter?.title ?? "").localeCompare(
          String(right.page.frontmatter?.title ?? ""),
        )
      })
      .slice(0, Math.max(1, Number(options.limit) || 5))

    return h("nav", { class: "writing-index", "aria-label": "Latest writing" }, [
      h("div", { class: "writing-index-heading" }, [
        h("h2", null, "Latest writing"),
        h("span", { "aria-hidden": "true" }, "✎"),
      ]),
      entries.length
        ? h(
            "ul",
            { class: "writing-index-list" },
            entries.map(({ page, date }) =>
              h(
                "li",
                { key: page.slug },
                h("a", { class: "internal", href: `/${page.slug}` }, [
                  h("span", null, page.frontmatter?.title ?? page.slug),
                  date
                    ? h(
                        "time",
                        { datetime: date.toISOString() },
                        new Intl.DateTimeFormat("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        }).format(date),
                      )
                    : null,
                ]),
              ),
            ),
          )
        : h("p", { class: "writing-index-empty" }, "The first public note is still being written."),
      h(
        "a",
        { class: "internal writing-index-more", href: options.linkToMore || "/notes" },
        "All writing →",
      ),
    ])
  }

  WritingListComponent.displayName = "Latest Writing"
  return WritingListComponent
}
