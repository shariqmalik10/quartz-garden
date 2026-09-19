export type CollectionKey = "writing" | "quotes" | "links"
export type ItemStatus = "public" | "draft" | "private"

export type VaultItem = {
  collection: CollectionKey
  path: string
  title: string
  status: ItemStatus
  detail: string
  modifiedAt?: string
  revision?: string
  body: string
  frontmatter: Record<string, unknown>
}

export type CollectionSummary = {
  key: CollectionKey
  label: string
  description: string
  total: number
  public: number
  draft: number
  private: number
}

export type ActivityItem = {
  sha: string
  message: string
  committedAt: string
  repository: "vault" | "site"
  url?: string
}

export type SyncHealth = {
  status: "connected" | "demo" | "attention"
  source: string
  branch: string
  revision: string
  checkedAt: string
  message: string
}

export type VaultArea = { name: string; visibility: "garden" | "private" }

export type VaultSnapshot = {
  generatedAt: string
  health: SyncHealth
  collections: CollectionSummary[]
  areas: VaultArea[]
  items: VaultItem[]
  activity: ActivityItem[]
}
