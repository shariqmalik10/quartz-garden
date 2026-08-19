import { h } from "preact"

const quoteDate = (page) =>
  page.dates?.published ?? page.dates?.created ?? page.dates?.modified ?? null

const textValue = (value) => (typeof value === "string" ? value.trim() : "")

export const Quotes = (userOptions = {}) => {
  const options = { limit: 4, linkToMore: "/quotes", ...userOptions }

  const QuotesRail = ({ allFiles, fileData }) => {
    if (fileData.slug !== "index") return null

    const quotes = allFiles
      .filter((page) => page.slug?.startsWith("quotes/") && page.slug !== "quotes/index")
      .map((page) => {
        const frontmatter = page.frontmatter ?? {}
        return {
          page,
          quote: textValue(frontmatter.quote) || textValue(frontmatter.title),
          author: textValue(frontmatter.author) || textValue(frontmatter.attribution),
          source: textValue(frontmatter.source),
          sourceUrl: textValue(frontmatter.sourceUrl),
          date: quoteDate(page),
        }
      })
      .filter((entry) => entry.quote)
      .sort((left, right) => (right.date?.getTime?.() ?? 0) - (left.date?.getTime?.() ?? 0))

    const visibleQuotes = quotes.slice(0, Math.max(1, Number(options.limit) || 4))

    return h(
      "aside",
      { class: "quotes-rail", "aria-labelledby": "quotes-rail-title" },
      h("div", { class: "quotes-heading" }, [
        h("span", { class: "quotes-mark", "aria-hidden": "true" }, "❝"),
        h("div", null, [
          h("h2", { id: "quotes-rail-title" }, "Quotes I collected"),
          h("p", null, "small lines worth carrying"),
        ]),
      ]),
      visibleQuotes.length > 0
        ? h(
            "ol",
            { class: "quotes-list" },
            visibleQuotes.map(({ page, quote, author, source, sourceUrl, date }) =>
              h(
                "li",
                { key: page.slug },
                h("a", { class: "internal quote-entry", href: `/${page.slug}` }, [
                  h("blockquote", null, h("p", null, quote)),
                  author || source
                    ? h("footer", null, [
                        author ? h("cite", null, `— ${author}`) : null,
                        source
                          ? h(
                              "span",
                              { class: "quote-source" },
                              sourceUrl
                                ? h("span", { title: sourceUrl }, `${author ? " · " : ""}${source}`)
                                : `${author ? " · " : ""}${source}`,
                            )
                          : null,
                      ])
                    : null,
                  date
                    ? h(
                        "time",
                        { datetime: date.toISOString() },
                        new Intl.DateTimeFormat("en-US", {
                          month: "short",
                          day: "2-digit",
                          year: "numeric",
                        }).format(date),
                      )
                    : null,
                ]),
              ),
            ),
          )
        : h("p", { class: "quotes-empty" }, "The first line is waiting to be collected."),
      quotes.length > visibleQuotes.length || options.linkToMore
        ? h(
            "a",
            { class: "quotes-more internal", href: options.linkToMore || "/quotes" },
            "open the quote drawer →",
          )
        : null,
    )
  }

  QuotesRail.displayName = "Quotes I Collected"
  return QuotesRail
}
