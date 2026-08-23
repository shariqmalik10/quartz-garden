import { h } from "preact"

const quoteDrawerScript = `
function setupQuotesDrawer() {
  const openButton = document.querySelector("[data-quotes-open]")
  const dialog = document.getElementById("quotes-drawer")
  if (!(openButton instanceof HTMLButtonElement) || !(dialog instanceof HTMLDialogElement)) return

  const closeButton = dialog.querySelector("[data-quotes-close]")
  const openDrawer = () => {
    if (!dialog.open) dialog.showModal()
    openButton.setAttribute("aria-expanded", "true")
  }
  const closeDrawer = () => dialog.close()
  const closeFromBackdrop = (event) => {
    if (event.target === dialog) closeDrawer()
  }
  const returnFocus = () => {
    openButton.setAttribute("aria-expanded", "false")
    openButton.focus()
  }

  openButton.addEventListener("click", openDrawer)
  closeButton?.addEventListener("click", closeDrawer)
  dialog.addEventListener("click", closeFromBackdrop)
  dialog.addEventListener("close", returnFocus)

  window.addCleanup?.(() => {
    openButton.removeEventListener("click", openDrawer)
    closeButton?.removeEventListener("click", closeDrawer)
    dialog.removeEventListener("click", closeFromBackdrop)
    dialog.removeEventListener("close", returnFocus)
  })
}

document.addEventListener("nav", setupQuotesDrawer)
`

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

    const quoteList = (entries, className) =>
      h(
        "ul",
        { class: className },
        entries.map(({ page, quote, author, source, sourceUrl, date }) =>
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
                          { class: "quote-source", title: sourceUrl || undefined },
                          `${author ? " · " : ""}${source}`,
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
                      day: "numeric",
                      year: "numeric",
                    }).format(date),
                  )
                : null,
            ]),
          ),
        ),
      )

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
        ? quoteList(visibleQuotes, "quotes-list")
        : h("p", { class: "quotes-empty" }, "The first line is waiting to be collected."),
      quotes.length > visibleQuotes.length || options.linkToMore
        ? [
            h(
              "button",
              {
                type: "button",
                class: "quotes-more",
                "data-quotes-open": true,
                "aria-controls": "quotes-drawer",
                "aria-expanded": "false",
                "aria-haspopup": "dialog",
              },
              "open the quote drawer →",
            ),
            h(
              "dialog",
              {
                id: "quotes-drawer",
                class: "quotes-drawer",
                "aria-labelledby": "quotes-drawer-title",
              },
              h("div", { class: "quotes-drawer-sheet" }, [
                h("header", { class: "quotes-drawer-header" }, [
                  h("div", null, [
                    h("h2", { id: "quotes-drawer-title" }, "Quotes I collected"),
                    h("p", null, `${quotes.length} small lines worth carrying`),
                  ]),
                  h(
                    "button",
                    { type: "button", class: "quotes-close", "data-quotes-close": true },
                    "Close",
                  ),
                ]),
                quoteList(quotes, "quotes-list quotes-list-all"),
                h(
                  "a",
                  { class: "internal quotes-archive-link", href: options.linkToMore || "/quotes" },
                  "Visit the quote archive →",
                ),
              ]),
            ),
          ]
        : null,
    )
  }

  QuotesRail.displayName = "Quotes I Collected"
  QuotesRail.afterDOMLoaded = quoteDrawerScript
  return QuotesRail
}
