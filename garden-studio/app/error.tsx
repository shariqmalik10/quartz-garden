"use client"

export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <main className="simple-state">
      <span aria-hidden="true">!</span>
      <p className="eyebrow">The connection stumbled</p>
      <h1>Garden Studio could not finish this read.</h1>
      <p>Nothing was changed. Check the connection and try once more.</p>
      <button className="primary-button" type="button" onClick={reset}>
        Try again
      </button>
    </main>
  )
}
