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
    let mediaPolicy: VaultArea["mediaPolicy"] = "reference"
    if (yaml) {
      try {
        const data = YAML.parse(yaml[1]) as { visibility?: unknown; media_policy?: unknown }
        visibility = data?.visibility === "garden" ? "garden" : "private"
        mediaPolicy = data?.media_policy === "owned" ? "owned" : "reference"
      } catch {
        visibility = "private"
        mediaPolicy = "reference"
      }
    }
    areas.push({ name: match[1], visibility, mediaPolicy })
  }
  return areas.toSorted((a, b) => a.name.localeCompare(b.name))
}
