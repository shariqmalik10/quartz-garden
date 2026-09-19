# Garden Studio CMS plan

Status: approved direction, implementation in checkpoints  
Last updated: 2026-09-19

Implementation progress on `codex/garden-studio`:

- Checkpoint 0 complete: plan recorded.
- Checkpoint 1 complete: narrow publishing pipeline and combined preflight.
- Checkpoint 2 complete: versioned contracts, file-level audit, collision checks,
  and dry-run migration tooling.
- Checkpoint 3 complete: authenticated read-only Garden Studio, isolated Vercel project, and managed collection browser.
- Checkpoint 4 implementation complete: Obsidian-compatible editor, conditional Git writes, conflict handling, revision restore, and deep links.
- Checkpoints 5–6 not started.

## Decision

Build a small private, authenticated **Garden Studio** that edits the same Markdown content as Obsidian. Obsidian and the private vault repository remain the source of truth; Garden Studio is a faster second editor, not a replacement database. Publishing continues through narrow, validated exporters into the public Quartz repository.

This preserves plain files, offline editing, backlinks, Git history, and Quartz compatibility while removing the need to manually move files or run publishing commands for routine changes.

## Goals

- Create and edit writings, quotes, saved links, and later other site modules from a browser.
- Keep every editable item available as ordinary Markdown in Obsidian.
- Keep private material out of the public Quartz repository by construction.
- Provide drafts, validation, revision history, preview links, and an explicit publish action.
- Avoid changing Quartz internals so upstream Quartz updates remain reviewable.
- Make every rollout step independently testable and reversible.

## Non-goals

- Replacing Obsidian with a proprietary content database.
- Publishing the whole vault.
- Letting a browser hold a long-lived GitHub personal access token.
- Editing generated folders such as `content/garden-sync/` by hand.
- Changing the current production domain during the CMS build.
- Building collaboration, comments, or multiple editorial roles in the first version.

## Current system

| Role               | Current location                         | Rule                                                    |
| ------------------ | ---------------------------------------- | ------------------------------------------------------- |
| Canonical vault    | `/Users/shariq/Documents/Obsidian Vault` | Private source of truth                                 |
| Private backup     | `shariqmalik10/obsidian-vault-private`   | Full vault history; never exposed to Vercel             |
| Public site        | `shariqmalik10/quartz-garden`            | Contains only public content and site code              |
| Website renderer   | Quartz                                   | Reads the public repository's `content/` tree           |
| Preview hosting    | Vercel                                   | Branch and pull-request previews                        |
| Framework upstream | `jackyzha0/quartz`                       | Pulled through the `upstream` remote on review branches |

The existing publication boundary already has three focused exporters:

- area captures and blog links: `scripts/export-garden.mjs`
- quotes: `scripts/export-quotes.mjs`
- long-form writing: `scripts/export-writing.mjs`

Known gaps to fix before adding the CMS:

1. The private-vault workflow does not watch `Writing/**` or run the writing exporter.
2. The legacy generic Obsidian sync configuration says `Writings/`, while the real vault uses `Writing/`. It can also copy broader material than the narrow exporters and should not be part of the supported publishing path.
3. The vault has no first-class writing template even though the public repository documents one.
4. Local and browser edits need a visible conflict policy rather than silent last-write-wins behavior.
5. Export validation needs one combined, readable report before it can power a publish button.

## Target architecture

```text
Obsidian on Mac                         Garden Studio in browser
      |                                          |
      | edits Markdown                           | authenticated edits
      v                                          v
local private vault  <---- Git history ---->  private vault repository
                                                   |
                                                   | validated exporters
                                                   v
                                      public Quartz review branch + PR
                                                   |
                                                   | Vercel preview
                                                   v
                                           explicit merge to main
                                                   |
                                                   v
                                            public Quartz site
```

### Source-of-truth rule

The private vault repository is the coordination point between the Mac and Garden Studio. Each browser save reads the current file and its Git object identity, then performs a conditional write. If the file changed after the editor loaded it, the save stops and shows a comparison; it never silently overwrites newer work.

The local vault keeps its normal pull/rebase-before-push flow. A conflicting local edit remains local until the user resolves it. Failed syncs must be visible in logs and in Garden Studio's health screen.

### Publication rule

Garden Studio never writes directly to the website's `main` branch. A publish request:

1. validates selected private-vault content;
2. runs all relevant exporters in a temporary checkout;
3. builds Quartz;
4. creates or updates a dedicated public review branch;
5. opens or updates a pull request;
6. returns the Vercel preview link; and
7. merges only after an explicit Publish confirmation and green checks.

This makes preview and publication different actions. A failed exporter or build produces no public content commit.

## Content contracts

All managed content uses YAML frontmatter plus Markdown. The CMS presents friendly fields, but saves the same files Obsidian can edit.

### Writing

Source: `Writing/Blogs/<slug>.md`

```yaml
---
kind: writing
title: A clear title
slug: a-clear-title
date: 2026-09-19
visibility: private
draft: true
description: Optional summary
tags: []
---
```

Only `visibility: public` with `draft: false` is exportable.

### Quote

Source: `Quotes/Entries/<date>-<slug>.md`

```yaml
---
kind: quote
quote: The line worth keeping.
author: Optional author
source: Optional source
sourceUrl: https://example.com
captured_at: 2026-09-19T12:00:00+04:00
publish: false
---
```

### Saved link or blog

Source: `Areas/<Area>/Captures/<capture-id>.md`

```yaml
---
id: gd-20260919-example
kind: capture
title: Extracted page title
source: https://example.com
source_type: web
captured_at: 2026-09-19T12:00:00+04:00
area: "[[Blogs]]"
tags: [capture, blog]
metadata_status: complete
attachments: []
---
```

The area's map note remains the publication allowlist. A new area defaults to private.

### Direct site page

Home, About, Now, and project pages currently live directly in the public repository. They should join the Studio only after the private-vault collections are stable. Until then, Garden Studio labels them as repository-managed and does not pretend they are vault-backed.

## Garden Studio experience

### Dashboard

- collection cards for Writing, Quotes, Saved links, and publication activity;
- counts for drafts, publishable changes, conflicts, and failed validations;
- last vault sync and last successful site deployment;
- quick actions: New writing, Add quote, Save link, Review changes.

### Collection views

- search and filters;
- status chips for private, draft, ready, published, and changed since publish;
- title, modified time, destination, and validation state;
- bulk selection for preview, never for destructive deletion in the first version.

### Editor

- form fields for required metadata;
- Markdown body editor with preview;
- save status and validation beside the action that caused it;
- **Save draft**, **Preview changes**, **Publish**, and **Open in Obsidian** actions;
- raw frontmatter view behind an advanced disclosure, not as the default UI.

`obsidian://open?vault=...&file=...` is used only to open the local app. Obsidian URI is not treated as a remote sync API.

### History and conflicts

- show recent commits affecting the file;
- allow restoring a previous version by creating a new commit;
- on a stale save, show Base, Mine, and Latest with an explicit retry or manual merge;
- preserve the unsaved editor text locally while a conflict is resolved.

## Authentication and security

- Use an allowlisted account for the first version.
- Use server-side sessions with secure, HTTP-only cookies.
- Access GitHub through a GitHub App installation token scoped to the two repositories. Tokens are short-lived and never sent to the browser.
- Give the private repository `contents: write`; give the public repository only the permissions needed to create a branch and pull request.
- Keep Vercel preview secrets separate from production secrets.
- Validate paths server-side against a collection registry; never accept an arbitrary repository path from the client.
- Block credentials, private keys, private wikilinks, and disallowed personal details before export.
- Log content mutations and publication events without logging secrets or full private document bodies.

References:

- [GitHub repository contents API](https://docs.github.com/en/rest/repos/contents)
- [GitHub App installation tokens](https://docs.github.com/en/rest/apps/installations)
- [Obsidian URI](https://help.obsidian.md/Extending%2BObsidian/Obsidian%2BURI)
- [Vercel Git previews](https://vercel.com/docs/git)
- [Vercel environment variables](https://vercel.com/docs/environment-variables)

## Media policy

The first release supports existing vault-relative attachments and URL-only saved links. A later media checkpoint adds upload, naming, ownership, and size checks.

- owned files live below `Attachments/Captures/<capture-id>/`;
- third-party media remains a remote reference unless explicitly marked owned;
- the exporter, not the editor, decides which assets cross the public boundary;
- uploads reject executable files and enforce size/type limits;
- deleting a note does not automatically delete shared media.

## Checkpoints

Each checkpoint gets its own commit or small commit series, automated checks, and a written verification result. A checkpoint must pass before work begins on the next one.

### Checkpoint 0 — Record the plan

Deliverables:

- this document;
- isolated `codex/garden-studio` branch based on public `main`;
- no behavior changes.

Exit gate: documentation formatting passes and the commit contains only the plan.

### Checkpoint 1 — Stabilize the existing publishing pipeline

Deliverables:

- private workflow watches `Writing/**` and runs the writing exporter;
- a writing template is available inside the vault;
- supported publishing uses the three narrow exporters, not the generic folder copier;
- a combined dry-run report covers garden captures, quotes, and writing;
- documentation names `main` as the public target and explains failures/conflicts;
- current exporter test suites and a real-vault dry run pass without mutating published content.

Exit gate: a private test change can create a public review branch, pass CI, and provide a Vercel preview without merging or changing the production domain.

### Checkpoint 2 — Formalize schemas and migrations

Deliverables:

- versioned collection registry and schemas;
- consistent validation errors shared by scripts and the future UI;
- duplicate slug/ID and unsafe path detection;
- fixture-based migration for existing files;
- publication report lists included, skipped, and blocked files with reasons.

Exit gate: every existing managed file either validates or appears in an explicit migration report; no silent coercion.

### Checkpoint 3 — Read-only Garden Studio

Deliverables:

- authenticated application shell;
- dashboard, collections, search, file preview, publication history, and sync health;
- server-side GitHub App integration;
- repository and path allowlists.

Exit gate: the deployed preview can browse all managed collections while being unable to mutate either repository.

### Checkpoint 4 — Draft editing

Deliverables:

- create/edit writing, quotes, and captures;
- Markdown preview and friendly metadata forms;
- conditional Git writes and visible conflicts;
- revision history and safe restore;
- Open in Obsidian deep link.

Exit gate: edits made in Studio appear in Obsidian after sync, edits made in Obsidian appear in Studio, and concurrent edits cannot silently overwrite each other.

### Checkpoint 5 — Preview and publish

Deliverables:

- change review screen;
- exporter/build job in an isolated checkout;
- public review branch and pull-request lifecycle;
- Vercel preview link shown in Studio;
- explicit merge/publish action and deployment status.

Exit gate: a writing, quote, and saved link each complete the full private-vault → preview → merge → public-site flow, with rollback demonstrated.

### Checkpoint 6 — More modules, media, and hardening

Deliverables:

- direct site pages and projects, after choosing their long-term source of truth;
- attachment upload and media browser;
- accessibility, responsive, and performance audit;
- backup/restore drill, rate limits, audit log, and operational runbook.

Exit gate: production readiness review passes and domain cutover remains a separate explicit decision.

## Testing strategy

- Unit tests for parsing, schemas, path rules, redaction, and export ownership.
- Fixture tests for legacy Markdown and migrations.
- Integration tests against temporary Git repositories.
- End-to-end tests for sign-in, edit, conflict, preview, and publish.
- Quartz build for every public review branch.
- Manual acceptance in the Vercel preview at the end of each UI checkpoint.

No test should require publishing to `main` or changing the production domain.

## Rollback

- Studio saves are ordinary Git commits and can be reverted by a new commit.
- Generated public content is owned by manifests and can be regenerated from a known private-vault revision.
- Publishing happens through a pull request, so abandoning a preview has no production effect.
- The legacy site and its Vercel project remain intact until a separate cutover decision.

## Decisions deferred until their checkpoint

1. Studio runtime: a small application within this repository or a sibling private repository. Decide before Checkpoint 3 based on deployment isolation and whether public source exposure is acceptable.
2. Authentication provider: Vercel-protected preview, Auth.js, or another provider. The requirement is one allowlisted account and server-side sessions.
3. Direct site pages: move them into a public section of the vault or keep repository-native editing. Decide before Checkpoint 6.
4. Automatic merge: start with explicit merge only. Reconsider automation after the complete flow is reliable.
