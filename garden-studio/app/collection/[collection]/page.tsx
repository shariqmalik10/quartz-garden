import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"

import { ItemLedger } from "@/components/item-ledger"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import type { CollectionKey, ItemStatus } from "@/lib/types"
import { getVaultSnapshot } from "@/lib/vault"

const keys: CollectionKey[] = ["writing", "quotes", "links"]

export const metadata: Metadata = { title: "Collection" }

export default async function CollectionPage({
  params,
  searchParams,
}: {
  params: Promise<{ collection: string }>
  searchParams: Promise<{ q?: string; status?: string }>
}) {
  const [{ collection }, query, session, snapshot] = await Promise.all([
    params,
    searchParams,
    requireSession(),
    getVaultSnapshot(),
  ])
  if (!keys.includes(collection as CollectionKey)) notFound()
  const key = collection as CollectionKey
  const summary = snapshot.collections.find((item) => item.key === key)!
  const search = (query.q || "").trim().toLowerCase()
  const status = keys.includes(query.status as CollectionKey)
    ? undefined
    : ((["public", "draft", "private"].includes(query.status || "") ? query.status : undefined) as
        ItemStatus | undefined)
  const items = snapshot.items.filter(
    (item) =>
      item.collection === key &&
      (!status || item.status === status) &&
      (!search || `${item.title} ${item.detail} ${item.path}`.toLowerCase().includes(search)),
  )
  return (
    <StudioShell session={session} current={`/collection/${key}`}>
      <header className="page-header collection-page-header">
        <div>
          <Link className="back-link" href="/">
            ← Overview
          </Link>
          <p className="eyebrow">
            Collection · {summary.total} {summary.total === 1 ? "item" : "items"}
          </p>
          <h1>{summary.label}</h1>
          <p>{summary.description}</p>
        </div>
        <dl className="collection-counts">
          <div>
            <dt>Public</dt>
            <dd>{summary.public}</dd>
          </div>
          <div>
            <dt>Draft</dt>
            <dd>{summary.draft}</dd>
          </div>
          <div>
            <dt>Private</dt>
            <dd>{summary.private}</dd>
          </div>
        </dl>
      </header>
      <form className="filter-bar" method="get">
        <label>
          <span className="visually-hidden">Search this collection</span>
          <input
            name="q"
            type="search"
            defaultValue={query.q}
            placeholder={`Search ${summary.label.toLowerCase()}…`}
          />
        </label>
        <label>
          <span className="visually-hidden">Filter by status</span>
          <select name="status" defaultValue={status || ""}>
            <option value="">All states</option>
            <option value="public">Public</option>
            <option value="draft">Draft</option>
            <option value="private">Private</option>
          </select>
        </label>
        <button type="submit">Apply</button>
        {(search || status) && <Link href={`/collection/${key}`}>Clear</Link>}
      </form>
      <section aria-label={`${summary.label} items`}>
        <ItemLedger items={items} />
      </section>
    </StudioShell>
  )
}
