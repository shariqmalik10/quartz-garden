import Link from "next/link"

import type { VaultItem } from "@/lib/types"
import { StatusPill } from "./status-pill"

function formatDate(value?: string) {
  if (!value) return "—"
  const date = new Date(value)
  return Number.isNaN(date.valueOf())
    ? value
    : new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric" }).format(
        date,
      )
}

export function ItemLedger({ items, compact = false }: { items: VaultItem[]; compact?: boolean }) {
  if (!items.length) {
    return (
      <div className="empty-ledger">
        <span aria-hidden="true">✳</span>
        <p>Nothing is filed here yet.</p>
      </div>
    )
  }
  return (
    <div className={`item-ledger${compact ? " compact" : ""}`}>
      <div className="ledger-heading" aria-hidden="true">
        <span>Title</span>
        <span>Status</span>
        <span>Updated</span>
      </div>
      {items.map((item) => (
        <Link
          className="ledger-row"
          href={`/entry?path=${encodeURIComponent(item.path)}`}
          key={item.path}
        >
          <span className="ledger-title">
            <strong>{item.title}</strong>
            <small>{item.detail}</small>
          </span>
          <StatusPill status={item.status} />
          <time dateTime={item.modifiedAt}>{formatDate(item.modifiedAt)}</time>
          <span className="row-arrow" aria-hidden="true">
            →
          </span>
        </Link>
      ))}
    </div>
  )
}
