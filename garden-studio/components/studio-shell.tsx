import Link from "next/link"
import type { ReactNode } from "react"

import type { StudioSession } from "@/lib/session"

const navigation = [
  { href: "/", label: "Overview", mark: "⌂" },
  { href: "/collection/writing", label: "Writing", mark: "W" },
  { href: "/collection/links", label: "Saved links", mark: "↗" },
  { href: "/collection/quotes", label: "Quotes", mark: "“" },
  { href: "/publish", label: "Review & publish", mark: "↑" },
  { href: "/history", label: "History", mark: "↻" },
  { href: "/health", label: "Connection", mark: "●" },
]

export function StudioShell({
  session,
  current,
  children,
}: {
  session: StudioSession
  current: string
  children: ReactNode
}) {
  return (
    <div className="studio-frame">
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <aside className="studio-sidebar">
        <Link className="studio-wordmark" href="/" aria-label="Garden Studio overview">
          <span>Garden</span>
          <strong>Studio</strong>
        </Link>
        <p className="studio-kicker">Publishing desk</p>
        <nav className="studio-navigation" aria-label="Studio navigation">
          {navigation.map((item) => (
            <Link
              href={item.href}
              key={item.href}
              className={current === item.href ? "active" : undefined}
              aria-current={current === item.href ? "page" : undefined}
            >
              <span aria-hidden="true">{item.mark}</span>
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="studio-profile">
          {session.avatarUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- GitHub avatar URL is session data.
            <img src={session.avatarUrl} alt="" width="32" height="32" />
          ) : (
            <span className="profile-initial" aria-hidden="true">
              {session.name.slice(0, 1)}
            </span>
          )}
          <span>
            <strong>{session.name}</strong>
            <small>{session.mode === "preview" ? "Demo session" : `@${session.login}`}</small>
          </span>
          <form action="/api/auth/logout" method="post">
            <button className="text-button" type="submit">
              Sign out
            </button>
          </form>
        </div>
      </aside>
      <main className="studio-main" id="main-content">
        {children}
      </main>
    </div>
  )
}
