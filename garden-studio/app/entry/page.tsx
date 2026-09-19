import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

import { StatusPill } from "@/components/status-pill"
import { StudioShell } from "@/components/studio-shell"
import { requireSession } from "@/lib/auth"
import { getVaultItem } from "@/lib/vault"

export const metadata: Metadata = { title: "Inspect item" }

function displayValue(value: unknown) {
  if (Array.isArray(value)) return value.join(", ")
  if (typeof value === "boolean") return value ? "true" : "false"
  if (value === null || value === undefined) return "—"
  if (typeof value === "object") return JSON.stringify(value)
  return String(value)
}

export default async function EntryPage({
  searchParams,
}: {
  searchParams: Promise<{ path?: string }>
}) {
  const [{ path = "" }, session] = await Promise.all([searchParams, requireSession()])
  const item = await getVaultItem(path)
  if (!item) notFound()
  return (
    <StudioShell session={session} current={`/collection/${item.collection}`}>
      <header className="page-header entry-header">
        <div>
          <Link className="back-link" href={`/collection/${item.collection}`}>
            ← Back to {item.collection === "links" ? "saved links" : item.collection}
          </Link>
          <p className="eyebrow">Read-only inspection</p>
          <h1>{item.title}</h1>
          <p>{item.detail}</p>
        </div>
        <StatusPill status={item.status} />
      </header>
      <div className="entry-grid">
        <article className="markdown-preview">
          <div className="preview-label">
            <span>Rendered note</span>
            <small>Edits arrive in a later checkpoint</small>
          </div>
          {item.body ? (
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{item.body}</ReactMarkdown>
          ) : (
            <p className="empty-copy">This entry is stored entirely in its properties.</p>
          )}
        </article>
        <aside className="properties-panel" aria-labelledby="properties-heading">
          <h2 id="properties-heading">Properties</h2>
          <dl>
            <div>
              <dt>File</dt>
              <dd>{item.path}</dd>
            </div>
            <div>
              <dt>State</dt>
              <dd>{item.status}</dd>
            </div>
            {Object.entries(item.frontmatter).map(([key, value]) => (
              <div key={key}>
                <dt>{key.replaceAll("_", " ")}</dt>
                <dd>{displayValue(value)}</dd>
              </div>
            ))}
          </dl>
        </aside>
      </div>
    </StudioShell>
  )
}
