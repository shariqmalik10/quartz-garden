import { h } from "preact"

const quoteDate = (page) =>
  page.dates?.published ?? page.dates?.created ?? page.dates?.modified ?? null

const textValue = (value) => (typeof value === "string" ? value.trim() : "")

const quoteSize = (quote) => {
  if (quote.length < 58) return "quote-field-short"
  if (quote.length > 190) return "quote-field-long"
  return "quote-field-medium"
}

export const QuoteArchive = () => {
  const QuoteArchiveComponent = ({ allFiles, fileData }) => {
    if (fileData.slug !== "quotes/index") return null

    const quotes = allFiles
      .filter((page) => page.slug?.startsWith("quotes/") && page.slug !== "quotes/index")
      .map((page) => {
        const frontmatter = page.frontmatter ?? {}
        return {
          slug: page.slug,
          quote: textValue(frontmatter.quote) || textValue(frontmatter.title),
          author: textValue(frontmatter.author) || textValue(frontmatter.attribution),
          source: textValue(frontmatter.source),
          date: quoteDate(page),
        }
      })
      .filter((entry) => entry.quote)

    return h("section", { class: "quote-field", "aria-label": "Collected quotes" }, [
      h("header", { class: "quote-field-intro" }, [
        h("span", { class: "quote-field-mark", "aria-hidden": "true" }, "❝"),
        h("div", null, [
          h("p", { class: "quote-field-count" }, `${quotes.length} small lines worth carrying`),
          h(
            "p",
            { class: "quote-field-note" },
            "Some arrived with names attached; others are kept exactly as I found them.",
          ),
        ]),
      ]),
      quotes.length > 0
        ? h(
            "ul",
            { class: "quote-field-list" },
            quotes.map(({ slug, quote, author, source, date }) =>
              h(
                "li",
                { key: slug, class: `quote-field-item ${quoteSize(quote)}` },
                h("figure", null, [
                  h("span", { class: "quote-field-item-mark", "aria-hidden": "true" }, "❝"),
                  h("blockquote", null, h("p", null, quote)),
                  author || source || date
                    ? h("figcaption", null, [
                        author ? h("cite", null, `— ${author}`) : null,
                        source
                          ? h(
                              "span",
                              { class: "quote-field-source" },
                              `${author ? " · " : ""}${source}`,
                            )
                          : null,
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
                      ])
                    : null,
                ]),
              ),
            ),
          )
        : h("p", { class: "quote-field-empty" }, "The first line is waiting to be collected."),
    ])
  }

  QuoteArchiveComponent.displayName = "Quote Archive"
  return QuoteArchiveComponent
}
