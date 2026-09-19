import Link from "next/link"
import { redirect } from "next/navigation"

import { authConfigured, readSession } from "@/lib/session"

const messages: Record<string, string> = {
  "invalid-state": "The sign-in request expired. Please try again.",
  "oauth-not-configured": "GitHub sign-in has not been configured for this deployment.",
  "oauth-failed": "GitHub could not complete this sign-in.",
  "not-allowed": "This GitHub account is not allowed into the Studio.",
  "preview-denied": "That preview key was not accepted.",
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>
}) {
  if (await readSession()) redirect("/")
  const { error } = await searchParams
  const demoEnabled =
    process.env.GARDEN_STUDIO_DEMO === "true" || process.env.VERCEL_ENV === "preview"
  return (
    <main className="login-page">
      <section className="login-card" aria-labelledby="login-title">
        <div className="login-mark" aria-hidden="true">
          ✳
        </div>
        <p className="eyebrow">Private publishing desk</p>
        <h1 id="login-title">Garden Studio</h1>
        <p className="login-intro">
          Read the state of your vault, review what is public, and follow each change before it
          reaches the garden.
        </p>
        {error && (
          <p className="form-notice error">{messages[error] || "Sign-in did not complete."}</p>
        )}
        {authConfigured() && (
          <Link className="primary-button" href="/api/auth/login">
            Continue with GitHub <span aria-hidden="true">→</span>
          </Link>
        )}
        {demoEnabled && (
          <form className="preview-form" action="/api/auth/preview" method="post">
            <input
              className="visually-hidden"
              name="username"
              value="preview"
              autoComplete="username"
              readOnly
              aria-hidden="true"
              tabIndex={-1}
            />
            <label htmlFor="preview-key">Preview key</label>
            <div>
              <input
                id="preview-key"
                name="key"
                type="password"
                autoComplete="current-password"
                required
              />
              <button type="submit">Open preview</button>
            </div>
            <small>Uses sample content. Your private vault is never loaded in demo mode.</small>
          </form>
        )}
        {!authConfigured() && !demoEnabled && (
          <p className="form-notice">This Studio needs its GitHub connection before it can open.</p>
        )}
      </section>
      <p className="login-footnote">Built as the quiet back room of the public garden.</p>
    </main>
  )
}
