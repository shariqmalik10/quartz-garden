# Repository and deployment contract

This document describes how the personal Quartz site, the private Obsidian vault,
Garden Drop, GitHub, and Vercel fit together. It is deliberately separate from
the Quartz documentation so that an upstream Quartz update does not silently
change the personal publishing contract.

## The preservation rule

The existing production site is `shariqmalik10/portfolio-website`, a separate
Next.js repository currently associated with `shariq.vercel.app`. It is the
legacy production site and must remain intact while the Quartz site is being
tested.

The Quartz site must not be pushed to a branch of that repository. The two
projects have different histories, build commands, content models, and Vercel
deployments. Keeping them in one repository would make a branch mistake capable
of changing the current production deployment.

Before changing the domain, create a non-moving archive pointer in the legacy
repository without changing its `main` branch:

```bash
git fetch origin main
git branch legacy-production-2026-08-19 origin/main
git tag -a legacy-production-2026-08-19 origin/main \
  -m "Archive the legacy production site before Quartz cutover"
git push origin \
  refs/heads/legacy-production-2026-08-19 \
  refs/tags/legacy-production-2026-08-19
```

The existing Vercel project and `shariq.vercel.app` should remain attached to
the legacy repository until the Quartz preview has been accepted. The old
Vercel project is the rollback path; the archive branch/tag is the source
rollback pointer.

## Recommended repository topology

Use an actual GitHub fork of `jackyzha0/quartz`, then rename the fork to the
personal site repository name if desired. The proposed names below are
placeholders until the repositories are created:

| Purpose                   | Repository                             | Visibility | Local remote   |
| ------------------------- | -------------------------------------- | ---------- | -------------- |
| Upstream Quartz framework | `jackyzha0/quartz`                     | public     | `upstream`     |
| Personal Quartz site      | `shariqmalik10/quartz-garden`          | public     | `origin`       |
| Obsidian source of truth  | `shariqmalik10/obsidian-vault-private` | private    | vault `origin` |
| Existing production site  | `shariqmalik10/portfolio-website`      | public     | legacy only    |

The Quartz worktree should eventually report remotes equivalent to:

```text
origin    git@github.com:shariqmalik10/quartz-garden.git
upstream  https://github.com/jackyzha0/quartz.git
```

The private vault should have only its private repository as `origin`. The
public repository must never contain `.obsidian`, `Private/`, credentials,
unpublished captures, or a private repository token.

## Branch contract

Use these branches consistently:

- `v5` tracks the upstream Quartz branch and contains no personal site work.
- `main` is the personal Quartz site branch. It is the only branch that should
  become the new Vercel production branch.
- `feat/**`, `feature/**`, `fix/**`, `chore/**`, `docs/**`, and `site/**` are
  development branches. Each receives GitHub CI and a Vercel preview when it
  is pushed or opened as a pull request.
- `upstream-update/**` is a temporary branch for reviewing an upstream Quartz
  update before merging it into `main`.

The current `feat/garden-drop-macos` branch is covered by the CI workflow in
[`.github/workflows/ci.yaml`](../.github/workflows/ci.yaml).

## Quartz history and upstream updates

The current local worktree began as a local snapshot, not as an ancestry-
preserving clone of the upstream repository. Adding `upstream` to that history
and immediately pulling `v5` would require an unrelated-history merge and may
surface conflicts in many files. Normalize the history once while creating the
personal fork:

1. Start from the fork's real `v5` history.
2. Transplant the personal site changes and the Garden Drop changes onto a
   personal `main` branch.
3. Keep upstream framework changes separate from personal configuration,
   content, plugins, styles, and scripts.
4. Run the complete CI command sequence before opening the merge request.

After that one-time normalization, review upstream updates as follows:

```bash
git fetch upstream v5
git switch -c upstream-update/2026-08-19 main
git merge --no-ff upstream/v5
npm ci
npm run install-plugins
npm run check
npm test
npx quartz build -d content
```

Resolve conflicts in a review branch, then merge that branch into `main`. Do
not use a force push or a blind upgrade on the live branch. The custom work
should stay concentrated in `content/`, `plugins/`, `quartz.config.yaml`,
custom styles/components, `scripts/`, and `vercel.json`; upstream files under
`quartz/` should be changed only when a deliberate compatibility fix is
required.

## GitHub CI

The personal repository uses one small workflow: [`.github/workflows/ci.yaml`](../.github/workflows/ci.yaml).
It runs for all pull requests, pushes to `main`, and pushes to the feature/
development branch families listed above. It also supports a manual run.

The job intentionally has only:

```text
contents: read
```

It performs these gates in order:

1. `npm ci` installs the lockfile-defined dependencies.
2. `npm run install-plugins` installs the Quartz plugins used by the config.
3. `npm run check` runs TypeScript and formatting checks.
4. `npm test` runs the repository tests.
5. `npx quartz build -d content` builds the actual personal site content.

The old upstream-only Cloudflare preview, Cloudflare v5 deploy, Docker image,
and release-tag jobs are intentionally not part of this repository. Vercel
provides the website preview/deployment, so those jobs would add credentials
and failure modes without helping the personal site.

## Obsidian-to-Quartz publication boundary

The private vault remains the source of truth. Garden Drop saves locally first;
the nightly backup is a separate operation. At 23:00 Asia/Riyadh, the macOS
launch agent should:

1. Acquire a lock so only one backup runs.
2. Pull/rebase the private repository with autostash and no force push.
3. Commit eligible vault changes.
4. Push the private vault repository over SSH.

A private-repository GitHub Action then checks out the vault and the public
Quartz repository, runs the publication exporter, and pushes only validated
generated content. Riyadh is UTC+3 year-round, so the equivalent UTC time is
20:00.

The exporter boundary is deliberately narrow:

```text
public Quartz repository
└── content/garden-sync/     # exporter-owned subtree only
```

The exporter must:

- export only areas explicitly marked `visibility: garden`;
- inject `publish: true` into generated frontmatter;
- derive public paths from the area's `site_slug`;
- omit third-party downloaded media unless `media_policy: owned`;
- replace private wikilinks with `[private reference omitted]`;
- block email, LinkedIn, phone, résumé, credential, and secret-like content;
- maintain a generated manifest inside `content/garden-sync/`;
- remove only generated files listed by that manifest; and
- leave handcrafted pages, site configuration, and other `content/` folders
  untouched.

The exporter must validate generated Markdown, links, and the Quartz build
before creating a public commit. A failed validation must produce no public
commit. This prevents an incomplete or accidentally private capture from
reaching Vercel.

The private workflow should use a dedicated SSH deploy key stored only as the
private-repository secret `PUBLIC_REPO_DEPLOY_KEY`. Its public half must be a
write-enabled deploy key on the single public Quartz repository. It must not be
copied into the public repository, the vault, or the macOS app.

## Vercel preview and production behavior

Create a new Vercel project for the public Quartz repository. Do not reconnect
the existing legacy Vercel project while testing.

The checked-in [`vercel.json`](../vercel.json) defines the build contract:

```text
install: npm ci
build:   npm run install-plugins && npx quartz build
output:  public
```

Vercel should use `main` as the new project's production branch. Pushes and
pull requests from feature branches receive generated Vercel preview URLs.
The preview URL is the correct link for acceptance testing; it does not change
`shariq.vercel.app`.

The final domain cutover is a separate, explicit operation:

1. Verify a feature-branch preview.
2. Verify a `main` preview/build and the private-vault publication flow.
3. Confirm the generated garden pages, links, attachments, and redaction.
4. Point `shariq.vercel.app` at the new Vercel project.
5. Keep the legacy Vercel project and the legacy archive branch/tag available
   for rollback.

No production-domain change is implied by pushing the Quartz feature branch.
