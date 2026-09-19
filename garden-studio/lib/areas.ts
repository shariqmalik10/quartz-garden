import YAML from "yaml"

import type { VaultArea } from "./types"

export function areasFromDocuments(
  documents: Array<{ path: string; content: string }>,
): VaultArea[] {
  const areas: VaultArea[] = []
  for (const document of documents) {
    const match = document.path.match(/^Areas\/([^/]+)\/\1\.md$/)
    if (!match) continue
    const yaml = document.content.match(/^---\r?\n([\s\S]*?)\r?\n---/)
    let visibility: VaultArea["visibility"] = "private"
    if (yaml) {
      try {
        const data = YAML.parse(yaml[1]) as { visibility?: unknown }
        visibility = data?.visibility === "garden" ? "garden" : "private"
      } catch {
        visibility = "private"
      }
    }
    areas.push({ name: match[1], visibility })
  }
  return areas.toSorted((a, b) => a.name.localeCompare(b.name))
}
