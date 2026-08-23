const atlasNavigationScript = `
function setupAtlasNavigation() {
  const article = document.querySelector("article.inspiration-atlas")
  if (!(article instanceof HTMLElement) || article.dataset.atlasReady === "true") return

  const search = article.querySelector("#atlas-filter")
  const clearButton = article.querySelector("[data-atlas-clear]")
  const status = article.querySelector("[data-atlas-status]")
  const empty = article.querySelector("[data-atlas-empty]")
  const groups = Array.from(article.querySelectorAll("[data-atlas-group]"))
  const jumpLinks = Array.from(article.querySelectorAll("[data-atlas-jump]"))
  if (!(search instanceof HTMLInputElement) || !(clearButton instanceof HTMLButtonElement)) return
  if (!(status instanceof HTMLElement) || !(empty instanceof HTMLElement) || groups.length === 0) return

  article.dataset.atlasReady = "true"
  const totalLinks = groups.reduce(
    (total, group) => total + group.querySelectorAll("[data-atlas-item]").length,
    0,
  )

  const update = () => {
    const query = search.value.trim().toLocaleLowerCase()
    let visibleLinks = 0

    for (const group of groups) {
      const label = (group.getAttribute("data-atlas-label") || "").toLocaleLowerCase()
      const categoryMatches = query.length > 0 && label.includes(query)
      const items = Array.from(group.querySelectorAll("[data-atlas-item]"))
      let visibleInGroup = 0

      for (const item of items) {
        const link = item.querySelector("a")
        const haystack = (
          label +
          " " +
          (item.textContent || "") +
          " " +
          (link?.getAttribute("href") || "")
        ).toLocaleLowerCase()
        const matches = query.length === 0 || categoryMatches || haystack.includes(query)
        item.hidden = !matches
        if (matches) visibleInGroup += 1
      }

      group.hidden = query.length > 0 && visibleInGroup === 0
      if (query.length > 0 && visibleInGroup > 0 && group instanceof HTMLDetailsElement) {
        group.open = true
      }

      const count = group.querySelector("[data-atlas-count]")
      const total = Number(count?.getAttribute("data-total")) || items.length
      if (count instanceof HTMLElement) {
        count.textContent = query.length > 0
          ? visibleInGroup + " of " + total + " links"
          : total + " links"
      }
      visibleLinks += visibleInGroup
    }

    clearButton.hidden = query.length === 0
    empty.hidden = visibleLinks > 0
    status.textContent = query.length > 0
      ? visibleLinks + " links matching “" + search.value.trim() + "”"
      : totalLinks + " links across " + groups.length + " collections"
  }

  const clearSearch = () => {
    search.value = ""
    update()
    search.focus()
  }

  const jumpHandlers = jumpLinks.map((link) => {
    const handler = () => {
      if (search.value.length > 0) {
        search.value = ""
        update()
      }
      const targetId = link.getAttribute("href")?.slice(1)
      const target = targetId ? document.getElementById(targetId) : null
      if (target instanceof HTMLDetailsElement) target.open = true
    }
    link.addEventListener("click", handler)
    return { link, handler }
  })

  search.addEventListener("input", update)
  clearButton.addEventListener("click", clearSearch)
  update()

  window.addCleanup?.(() => {
    search.removeEventListener("input", update)
    clearButton.removeEventListener("click", clearSearch)
    for (const { link, handler } of jumpHandlers) link.removeEventListener("click", handler)
    delete article.dataset.atlasReady
  })
}

document.addEventListener("nav", setupAtlasNavigation)
`

export const AtlasNavigation = () => {
  const AtlasNavigationComponent = () => null
  AtlasNavigationComponent.displayName = "Atlas Navigation"
  AtlasNavigationComponent.afterDOMLoaded = atlasNavigationScript
  return AtlasNavigationComponent
}
