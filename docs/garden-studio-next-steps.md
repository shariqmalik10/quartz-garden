# Garden Studio — implementation handoff and next steps

Last updated: 2026-09-20
Implementation branch: `codex/garden-studio`  
Latest checkpoint commit: `f447f72` (`fix: harden Studio operations`)
Current checkpoint: all feasible local implementation complete; CI and both Vercel previews green
Public repository PR: <https://github.com/shariqmalik10/quartz-garden/pull/6>  
Private vault workflow PR: <https://github.com/shariqmalik10/obsidian-vault-private/pull/1>
Studio preview: <https://garden-studio-git-codex-garden-studio-shariq-s-projects.vercel.app> (Vercel-auth protected)
Quartz branch preview: <https://shariq-quartz-garden-git-codex-garden-studio-shariq-s-projects.vercel.app> (Vercel-auth protected)

## Handoff status

Implementation is active on the isolated `codex/garden-studio` branch. This document is updated at every verified checkpoint so another session can resume without reconstructing decisions from chat history.

The Studio now has the safe editing and review-publishing foundation, expanded Markdown/Obsidian authoring tools, private saved-link attachments, operational safeguards, and a recovery runbook. All feasible local checkpoints are complete. Real-vault verification remains intentionally blocked until the GitHub App credentials are configured and private workflow PR #1 is reviewed and merged.

## Continuation log

- **2026-09-19 · Baseline repaired:** added the generated `garden-studio/next-env.d.ts` file to the repository-root Prettier ignore. Root checks, 191 tests, Studio checks, 6 Studio tests, and the Studio production build all pass locally. Richer editor work can now proceed from a green baseline.

- **2026-09-19 · Authoring tools complete:** added 17 Markdown and Obsidian commands, a `Cmd/Ctrl + K` searchable command palette, four writing templates, managed-note wikilink insertion, copyable current-note wikilinks, and live word/character/reading-time statistics. The implementation remains dependency-light, preserves plain Markdown, passed desktop and 390 px browser interaction checks, returned no Impeccable detector findings, passed 10 Studio tests, and completed a production build.

- **2026-09-19 · Private capture media complete:** added authenticated JPEG, PNG, WebP, GIF, and PDF uploads to `Attachments/Captures/<capture-id>/`, with signature and extension verification, an 8 MB limit, collision-safe filenames, strict path allowlists, GitHub App binary reads/writes, Obsidian attachment lists, automatic image embeds, and non-destructive reference removal. The editor reads each area’s existing `media_policy` and clearly explains `reference` versus `owned`; it never changes policy during upload. Browser verification covered first save, PNG upload, embed insertion, removal, policy switching, desktop and 390×844 layouts, and a zero-error console. Studio checks, 13 Studio tests, the production build, root checks, and all 198 repository tests pass.

- **2026-09-20 · Operational hardening complete:** added bounded streaming JSON parsing, pre-parse upload limits, strict runtime editor-payload validation, best-effort per-session/IP rate limits, generic browser-facing upstream errors, security headers, and a Connection checklist that reports configuration presence without values. Updated obsolete publishing-boundary copy and added `docs/garden-studio-operations.md` with conflict, restore, preview-abandonment, credential, rollback, and real-data readiness procedures. The hardened Studio passes 17 focused tests, all 202 repository tests, root checks, and a production build. Browser verification confirmed the deployment checklist at desktop and 390×844 widths, the expected CSP and anti-framing headers, and a zero-error console.

- **2026-09-20 · Final preview verification:** pushed `f447f72`, then verified GitHub `build-and-test`, the standalone `garden-studio` deployment, the Quartz branch deployment, and Vercel Preview Comments all passed on public PR #6. Both exact preview aliases are recorded above; Vercel authentication protection remains enabled, so unauthenticated requests intentionally redirect to login.

## Current state

### Completed in the public Quartz repository

1. **Publishing boundary and content contracts**
   - Narrow exporters for writings, quotes, and public area captures.
   - Versioned Markdown contracts.
   - Path, schema, collision, and sensitive-content checks.
   - Private content is excluded by construction.

2. **Read-only Garden Studio**
   - Separate Next.js application under `garden-studio/`.
   - Separate Vercel project, so the current Quartz production project and domain remain unchanged.
   - Signed server sessions, allowlisted GitHub login, repository/path allowlists, dashboard, collections, search, entry inspection, history, and connection health.
   - Safe synthetic demo mode that never loads the private vault.

3. **Obsidian-compatible authoring**
   - New/edit flows for writings, quotes, and saved links.
   - Friendly metadata forms plus generated YAML frontmatter.
   - Write, split, and preview views.
   - Markdown toolbar, wikilinks, browser draft recovery, `Cmd/Ctrl + S`, word count, and unsaved-change warning.
   - Conditional GitHub writes: a newer Obsidian edit cannot be overwritten silently.
   - Revision history and restore-as-a-new-commit.
   - `obsidian://open` deep links for opening the same source file in the local vault.

4. **Review and publish flow**
   - Review page listing entries currently eligible to cross the public boundary.
   - Dispatch of the private repository's `publish-garden.yml` workflow.
   - Fixed public review branch: `studio/garden-preview`.
   - Public pull-request creation/reuse, check status, and Vercel preview discovery.
   - Exact branch/head/base verification before merge.
   - Explicit confirmation by typing `publish`.
   - Demo mode can exercise the interface but cannot merge.

5. **Private saved-link attachments**
   - Authenticated private-vault upload and viewing routes for JPEG, PNG, WebP, GIF, and PDF files.
   - Signature, extension, size, filename, and path validation before GitHub writes.
   - Capture-local Obsidian storage and frontmatter attachment references.
   - Automatic image embed insertion and non-destructive reference removal.
   - Explicit `reference`/`owned` area-policy display without silent policy mutation.
   - Writing uploads remain intentionally unavailable until their exporter contract exists.

### Completed in the private vault branch

- The publishing workflow defaults to `studio/garden-preview`.
- It explicitly refuses `main` as the export target.
- The repository Actions variable is set to `PUBLIC_QUARTZ_BRANCH=studio/garden-preview`.
- These changes are still in private PR #1 and are not active on the private repository's default branch until that PR is reviewed and merged.

### Deliberately unchanged

- The current Quartz production domain and its Vercel project.
- The existing live Obsidian vault at `/Users/shariq/Documents/Obsidian Vault`.
- Public repository `main`.
- Private repository `main`.
- Any real GitHub App credentials; the deployed Studio is still configured as a synthetic demo.

## Resolved baseline issue

The root formatting failure caused by generated `garden-studio/next-env.d.ts` was fixed by adding that file to the repository-root Prettier ignore. The repaired baseline was committed before feature work, and repository-wide checks now pass.

## Active external blockers

The remaining blockers are configuration and approval boundaries, not unresolved local code failures:

1. Create and install the scoped GitHub App, then add its secrets to the separate Garden Studio Vercel project.
2. Review and merge private workflow PR #1 before attempting a real private-vault publish dispatch.
3. Run the disposable real-vault round trip and owned/reference export proof after those two prerequisites.
4. Do not merge public PR #6 or change the production domain until the real-data preview is explicitly approved.

## Recommended continuation order

Keep working in small commits on `codex/garden-studio`. Do not merge either pull request and do not change the production domain until the user reviews the final real-data preview.

### Step 1 — Stabilize and verify Checkpoint 5

Goal: make the existing branch green without changing behavior.

- Fix the root `next-env.d.ts` ignore issue.
- Re-run the full test/build suite.
- Verify the Checkpoint 5 Vercel deployment still opens in demo mode.
- Test the publishing console at desktop and phone widths.
- Confirm that the demo preview shows links for the exporter run, pull request, and website preview whenever those values exist.
- Confirm that the merge button remains disabled in demo mode.
- Confirm that no request can target public `main` directly.

Exit gate: public PR #6 is green and the demo publishing journey works end to end.

### Step 2 — Connect a real GitHub App

Goal: replace synthetic data with the private vault while keeping all credentials server-side.

Create one GitHub App and use its user authorization credentials for login. Install it only on:

- `shariqmalik10/obsidian-vault-private`
- `shariqmalik10/quartz-garden`

Required repository permissions:

- Contents: read and write
- Actions: read and write
- Pull requests: read and write
- Checks: read-only
- Deployments: read-only
- Metadata: read-only

Use this callback URL:

```text
https://<garden-studio-domain>/api/auth/callback
```

Set the following only in the separate Garden Studio Vercel project:

```text
GARDEN_STUDIO_SESSION_SECRET
GARDEN_STUDIO_ALLOWED_LOGIN=shariqmalik10
GITHUB_OAUTH_CLIENT_ID
GITHUB_OAUTH_CLIENT_SECRET
GITHUB_APP_ID
GITHUB_APP_INSTALLATION_ID
GITHUB_APP_PRIVATE_KEY
GARDEN_STUDIO_VAULT_REPOSITORY=shariqmalik10/obsidian-vault-private
GARDEN_STUDIO_PUBLIC_REPOSITORY=shariqmalik10/quartz-garden
GARDEN_STUDIO_VAULT_BRANCH=main
GARDEN_STUDIO_PUBLIC_PREVIEW_BRANCH=studio/garden-preview
GARDEN_STUDIO_OBSIDIAN_VAULT_NAME=Obsidian Vault
GARDEN_STUDIO_DEMO=false
```

Remove or disable `GARDEN_STUDIO_PREVIEW_KEY` for the real deployment. Never expose the private key, client secret, or installation token through `NEXT_PUBLIC_*`, browser JavaScript, logs, screenshots, or committed files.

Before enabling writes, verify:

- an unapproved GitHub account cannot sign in;
- the browser never receives repository credentials;
- only contract-approved vault paths are returned;
- an attempted write outside `Writing/**`, `Quotes/Entries/**`, or `Areas/*/Captures/**` is rejected;
- the public repository cannot be written by the content-save endpoint.

Exit gate: the Studio can read real managed content, but a test write is performed only on a temporary entry.

### Step 3 — Complete the Obsidian round trip

Goal: prove that Studio and Obsidian are two editors for the same Markdown source.

Use a disposable test writing, quote, and saved link.

For each type:

1. Create it in Studio as a private draft.
2. Confirm the private GitHub repository receives one ordinary Markdown commit.
3. Pull the private repository into the local Obsidian vault.
4. Confirm the note opens through the Studio's **Open in Obsidian** action.
5. Edit the note in Obsidian, commit, and push it.
6. Refresh Studio and confirm the edit appears.
7. Open the note in Studio, then create a competing Obsidian edit and push it.
8. Attempt the stale Studio save and confirm the conflict screen appears instead of overwriting the newer revision.
9. Test revision restore and confirm it creates a new commit rather than rewriting history.

The local vault should pull before editing and push after editing. If automatic Obsidian Git sync is enabled later, use pull-on-start/focus and a conservative periodic backup; do not force-push or auto-resolve conflicts.

Exit gate: all three content types complete the bidirectional round trip and the conflict test passes.

### Step 4 — Make the editor richer while keeping it fast

Goal: provide many useful editing options without turning the Studio into a slow, fragile page builder.

Recommended UI direction:

- Keep the current server-rendered shell and make only the editor surface interactive.
- Preserve the warm paper/navy/rust visual system and ledger-like information density.
- Use a lazy-loaded Markdown editor such as CodeMirror 6 for syntax highlighting, selection-aware commands, search/replace, line numbers, and keyboard navigation.
- Keep the lightweight textarea as a fallback if the enhanced editor fails to load.
- Continue using deferred preview rendering so typing never waits for Markdown rendering.
- Avoid a heavy block-editor dependency; Markdown must remain the stored format.

Add the following authoring tools in separate sub-checkpoints:

1. **Formatting and insertion**
   - H1–H4, bold, italic, strikethrough.
   - Bulleted, numbered, and task lists.
   - Blockquote, fenced code block with language, inline code, horizontal rule.
   - Tables, footnotes, callouts, links, images, embeds, and Obsidian wikilinks.
   - Undo/redo and visible keyboard shortcuts.

2. **Templates**
   - Essay.
   - Garden note.
   - Project/build log.
   - Reading note.
   - Link commentary.
   - Blank document.

   Applying a template should fill only empty fields unless the user explicitly confirms replacement.

3. **Obsidian-aware linking**
   - Search managed vault notes by title and path.
   - Insert `[[wikilinks]]` or embeds without typing paths manually.
   - Display incoming/outgoing managed links in a side panel.
   - Copy the current note's wikilink.
   - Keep **Open in Obsidian** visible after the first save.

4. **Metadata controls**
   - Tags with removable chips and suggestions from existing vault tags.
   - Slug availability check.
   - Summary, publication date, canonical/source URL, draft/public state.
   - Quote attribution and source.
   - Saved-link area and metadata completeness.
   - Read-only path, revision, contract version, and raw frontmatter under an Advanced disclosure.

5. **Productivity**
   - Command palette (`Cmd/Ctrl + K`).
   - Slash-command insertion menu.
   - Duplicate as draft.
   - Local recovery timestamp and one-click discard.
   - Find/replace.
   - Word, character, and estimated reading-time counts.

Do not add destructive deletion yet. An archive/private action is safer and remains recoverable through Git.

Performance targets:

- typing feedback stays under one animation frame for normal notes;
- editor JavaScript is loaded only on new/edit routes;
- preview updates are deferred and large documents do not rerender the whole application shell;
- no layout shift when the editor or toolbars load;
- all actions remain keyboard reachable.

Exit gate: a long writing can be authored comfortably on desktop, and essential metadata/save actions remain usable on a phone.

### Step 5 — Add owned media safely

**Status: implemented and locally verified for saved-link captures; real-vault export proof awaits GitHub App setup.**

Goal: support images and PDFs that remain private until a managed entry is published.

Start with saved-link captures because the existing garden exporter already understands owned capture attachments.

Recommended storage layout:

```text
Attachments/Captures/<capture-id>/<safe-filename>
```

Implementation requirements:

- Accept JPEG, PNG, WebP, GIF, and PDF only.
- Validate both declared MIME type and file signature.
- Enforce a conservative per-file size limit, initially 8 MB.
- Normalize filenames and prevent absolute paths, `..`, control characters, and collisions.
- Upload only to the private vault through the GitHub App.
- Add an Obsidian embed such as `![[Attachments/Captures/...]]` and update the entry's `attachments` list.
- Show a small media browser for files already attached to the entry.
- Allow removing an attachment reference without deleting the source binary.
- Treat permanent deletion as a separate, confirmation-gated future feature.

The parent area's `media_policy` controls publication:

- `reference`: source media stays private and the public exporter omits it.
- `owned`: the exporter copies the allowlisted attachment into the generated public area.

Do not silently change an area's media policy during upload. Show the policy and explain whether the attachment will publish.

After captures are proven, add a specific writing-attachment contract and exporter behavior before exposing writing uploads. Do not upload writing media until the writing exporter can copy and rewrite those references safely.

Exit gate: an uploaded test image appears in Obsidian, remains absent from a reference-policy public export, and appears correctly in an owned-policy preview.

### Step 6 — Decide the source of truth for pages and projects

Recommendation: keep Obsidian as the canonical source and add explicit contracts rather than editing handcrafted public-repository files directly.

Proposed private-vault layout:

```text
Site/
  Pages/
  Projects/
```

Before coding:

- inventory the existing handcrafted `content/about.md`, `content/now.md`, `content/colophon.md`, and `content/projects/**` files;
- define which remain handcrafted and which become vault-managed;
- create separate `page` and `project` contract versions;
- reserve generated output paths so exporters cannot replace handmade content accidentally;
- create a dry-run migration report;
- add fixture tests for every existing page/project shape.

Do not reuse the generic writing contract for projects unless their public route and metadata are genuinely the same. The exporter, not the UI, must own the mapping from a private source file to a public Quartz path.

Exit gate: every migrated page/project is either explicitly generated or explicitly left handmade, with no ambiguous ownership.

### Step 7 — Operations and security hardening

**Status: locally complete; real credential and workflow drills remain externally gated.**

Goal: make failures understandable and writes appropriately constrained.

- Add best-effort per-session/IP rate limits to save, restore, upload, preview, and merge endpoints.
- Keep origin checks on every mutation.
- Add maximum request sizes before parsing bodies.
- Redact repository API errors before returning them to the browser.
- Keep Git commits as the authoritative audit log.
- Expand the History screen to distinguish Studio saves, restores, exports, and public merges.
- Add workflow-run and preview-branch health to the Connection screen.
- Update its old wording: public preview and explicit merge now exist.
- Add a setup checklist that reports only whether required variables are configured, never their values.
- Add a warning when the private workflow PR or required review branch is missing.
- Add security headers and review cookies for `Secure`, `HttpOnly`, and `SameSite=Lax` or stricter behavior.
- Verify Markdown rendering does not enable raw HTML or executable URLs.
- Preserve reduced-motion behavior and visible focus indicators.

Exit gate: mutation endpoints pass negative tests for missing session, bad origin, unsafe path, oversized upload, stale revision, and unapproved merge target.

### Step 8 — Backup and restore drill

Perform this before real publishing:

1. Record the private vault `main` revision.
2. Create and edit a disposable Studio entry.
3. Restore the prior version through Studio.
4. Confirm all versions remain visible in Git history.
5. Run exporters in dry-run mode against a clean checkout.
6. Build the Quartz review branch.
7. Abandon the review branch and verify public `main` and production are unchanged.
8. Repeat with an intentionally failing contract and verify no generated public files are committed.

Document the results and exact recovery commands in an operational runbook. Never use history-rewriting Git commands for routine recovery.

### Step 9 — Full real-data publication test

Only after the private workflow changes have been reviewed and merged:

1. Create one disposable writing, quote, and saved link.
2. Mark each ready/public in Studio.
3. Open **Review & publish** and inspect the boundary list.
4. Build the public review branch.
5. Confirm private drafts and unrelated vault folders are absent from the public diff.
6. Open the Vercel branch preview from Studio.
7. Check the exact public routes, metadata, links, mobile layout, and images.
8. Confirm every required check is green.
9. Type `publish` and merge only this reviewed head SHA.
10. Verify the existing production domain only updates through the normal public-repository deployment.
11. Revert the disposable entries with ordinary commits and repeat the preview to demonstrate rollback.

Exit gate: all three content types complete private vault → review branch → Vercel preview → confirmed merge → public Quartz, with a successful rollback demonstration.

## UI acceptance checklist

### Desktop

- Navigation, collection ledger, editor, history, health, and publishing pages align with the Garden Studio visual language.
- The primary action is visually clear without making every control a filled button.
- Long titles, paths, tags, and errors wrap or truncate safely.
- Sticky save state never covers content.
- Split preview remains readable from common laptop widths upward.

### Mobile

- Sidebar becomes a compact navigation surface without trapping focus.
- Save and publish actions remain reachable without horizontal scrolling.
- Editor properties and document canvas stack in the correct reading order.
- Toolbars scroll intentionally and show that more commands are available.
- Touch targets are at least 44 × 44 CSS pixels for essential controls.
- No two-column split preview is forced on a narrow screen.

### Accessibility

- One logical `h1` per page and no skipped heading structure.
- Every input has a programmatic label and error association.
- Save, conflict, upload, and publish states are announced through appropriate live regions.
- Keyboard-only users can create, edit, preview, restore, and publish.
- Focus returns to the triggering control after dialogs/menus close.
- Text and state colors meet WCAG AA contrast.
- Animations respect `prefers-reduced-motion`.

### Performance

- Keep the dashboard and read views mostly server-rendered.
- Lazy-load editor-only dependencies.
- Avoid downloading private content that is not visible on the current screen.
- Do not fetch the complete vault body set for a simple count if a tree/summary can provide it.
- Cache read-only GitHub data briefly, but never cache mutation responses or conflict-sensitive reads.

## Pull-request and deployment policy

- Public PR #6 remains the feature review PR.
- Private PR #1 remains the publishing-workflow review PR.
- Do not merge either PR solely to obtain a preview.
- Do not point the production domain at Garden Studio.
- Do not change the existing Quartz production domain during CMS development.
- Continue deploying Garden Studio as its own Vercel project with root directory `garden-studio`.
- Keep demo mode available for visual review, but use a separate protected deployment or real allowlisted login for private vault data.

## Suggested commit checkpoints

Use one reviewable commit for each boundary:

1. `fix: ignore generated Studio type shim`
2. `chore: configure real Studio connection`
3. `test: verify Obsidian round trip`
4. `feat: expand Markdown authoring tools`
5. `feat: add Obsidian-aware note links`
6. `feat: add private capture attachments`
7. `feat: add managed site modules`
8. `fix: harden Studio operations`
9. `docs: record production readiness drill`

Do not mix credential setup, content migration, media upload, and UI redesign into one checkpoint.

## Final readiness definition

Garden Studio is complete only when all of the following are true:

- CI and Vercel builds are green.
- Real allowlisted GitHub authentication works.
- No secret is exposed to the browser or repository.
- Studio and Obsidian round-trip edits without silent overwrites.
- Writings, quotes, and saved links publish through an isolated review branch.
- The exact Vercel preview is visible before merge.
- Attachments obey explicit media policy.
- Every managed public path has a single source of truth.
- Desktop, mobile, keyboard, reduced-motion, and contrast checks pass.
- Backup, conflict, exporter failure, and rollback drills pass.
- The existing production site remains preserved until a separate, explicit cutover decision.
