# Garden Studio

Garden Studio is the private, authenticated publishing desk for the Quartz garden. The Studio reads managed vault content and creates conditional Git commits for draft edits. It never silently overwrites a newer Obsidian change.

## Run locally

1. Copy `.env.example` to `.env.local` and fill in the values.
2. Run `npm install` in this directory.
3. Run `npm run dev` and open `http://localhost:3000`.

For local vault inspection, set `GARDEN_STUDIO_LOCAL_VAULT` to the absolute vault path. This mode is disabled on Vercel. For a design-only review, set `GARDEN_STUDIO_DEMO=true` and provide `GARDEN_STUDIO_PREVIEW_KEY`; only synthetic records are shown.

## GitHub setup

Create one GitHub App and use its OAuth credentials for Studio login:

- Set the user authorization callback to `https://YOUR-STUDIO-DOMAIN/api/auth/callback`. The allowed account is controlled by `GARDEN_STUDIO_ALLOWED_LOGIN`.
- Install the App only on `obsidian-vault-private` and `quartz-garden`.
- Repository permissions: **Contents: Read and write**, **Actions: Read and write**, **Pull requests: Read and write**, **Checks: Read-only**, **Deployments: Read-only**, and **Metadata: Read-only**.
- Put the App client ID and client secret in `GITHUB_OAUTH_CLIENT_ID` and `GITHUB_OAUTH_CLIENT_SECRET`. Put its App ID, installation ID, and private key in the matching server-only variables.

The app exchanges its private key for a short-lived installation token on the server. Neither the private key nor installation token is sent to the browser.

## Obsidian and publishing flow

Studio writes only contract-backed Markdown to the private vault repository. Obsidian receives those commits through its normal Git pull; Studio receives local Obsidian edits after they are pushed. The **Open in Obsidian** action uses the local `obsidian://open` protocol and the vault name configured by `GARDEN_STUDIO_OBSIDIAN_VAULT_NAME`.

The Review & publish screen dispatches `publish-garden.yml` in the private repository. That workflow validates the vault, exports only public entries, and pushes them to `studio/garden-preview` in the public Quartz repository. Studio then shows the exact pull request, required checks, and Vercel preview. A merge is possible only after checks pass and the user types `publish`. The production domain remains untouched until that reviewed pull request is merged.

Required repository settings:

- Private repository Actions variable: `PUBLIC_QUARTZ_BRANCH=studio/garden-preview`.
- Private repository Actions secrets: the existing deploy key and public repository connection used by `publish-garden.yml`.
- Public repository: Vercel branch previews enabled for pull requests.
- Protect `main`; do not let the export workflow push directly to it.

## Deploy separately on Vercel

Create a new Vercel project from the same repository and set its root directory to `garden-studio`. Add the environment variables from `.env.example`. This keeps Quartz's static build and deployment unchanged.

## Read boundary

Studio recognizes only contract-backed Markdown files in:

- `Writing/**`
- `Quotes/Quotes.md` and `Quotes/Entries/**`
- `Areas/<area>/<area>.md` and `Areas/<area>/Captures/**`

Unrecognized paths are not fetched or rendered. Markdown is rendered without raw HTML support.
