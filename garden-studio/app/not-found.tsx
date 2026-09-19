import Link from "next/link"

export default function NotFound() {
  return (
    <main className="simple-state">
      <span aria-hidden="true">✳</span>
      <p className="eyebrow">Nothing filed here</p>
      <h1>This page is not in the ledger.</h1>
      <Link className="primary-button" href="/">
        Return to overview
      </Link>
    </main>
  )
}
