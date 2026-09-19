# Garden Studio

Garden Studio is the private, authenticated publishing desk for the Quartz garden. The Studio reads managed vault content and creates conditional Git commits for draft edits. It never silently overwrites a newer Obsidian change.

## Run locally

1. Copy `.env.example` to `.env.local` and fill in the values.
2. Run `npm install` in this directory.
3. Run `npm run dev` and open `http://localhost:3000`.

For local vault inspection, set `GARDEN_STUDIO_LOCAL_VAULT` to the absolute vault path. This mode is disabled on Vercel. For a design-only review, set `GARDEN_STUDIO_DEMO=true` and provide `GARDEN_STUDIO_PREVIEW_KEY`; only synthetic records are shown.

## GitHub setup

Create two GitHub integrations:

- An OAuth app for Studio login. Its callback is `https://YOUR-STUDIO-DOMAIN/api/auth/callback`. The allowed account is controlled by `GARDEN_STUDIO_ALLOWED_LOGIN`.
- A GitHub App installed only on the private vault and public garden repositories. Give it **Contents: Read and write** on the private vault and **Metadata: Read-only** on both repositories. Public-site writes are introduced only by the publishing checkpoint.

The app exchanges its private key for a short-lived installation token on the server. Neither the private key nor installation token is sent to the browser.

## Deploy separately on Vercel

Create a new Vercel project from the same repository and set its root directory to `garden-studio`. Add the environment variables from `.env.example`. This keeps Quartz's static build and deployment unchanged.

## Read boundary

Studio recognizes only contract-backed Markdown files in:

- `Writing/**`
- `Quotes/Quotes.md` and `Quotes/Entries/**`
- `Areas/<area>/<area>.md` and `Areas/<area>/Captures/**`

Unrecognized paths are not fetched or rendered. Markdown is rendered without raw HTML support.
