import type { CollectionKey } from "./types"

export function collectionForPath(filePath: string): CollectionKey | null {
  if (/^Writing\/.+\.md$/.test(filePath)) return "writing"
  if (/^Quotes\/Entries\/[^/]+\.md$/.test(filePath)) return "quotes"
  if (/^Areas\/[^/]+\/Captures\/[^/]+\.md$/.test(filePath)) return "links"
  return null
}
