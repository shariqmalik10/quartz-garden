# Obsidian vault structure and publishing boundary

The canonical private source of truth is:

```text
/Users/shariq/Documents/Obsidian Vault
```

This stable vault was selected instead of the generated AI-engineering vault
under `Documents/Codex/.../outputs/`. Existing notes were preserved in place.
In particular, `Karage Work/` contains private business and infrastructure
material and is never in the public export allowlist.

## Current canonical tree

```text
Obsidian Vault/
├── Home.md
├── Areas/
│   ├── Design & Interaction/
│   │   ├── Design & Interaction.md
│   │   └── Captures/
│   ├── Blogs/
│   │   ├── Blogs.md
│   │   └── Captures/              # one saved blog or post per capture
│   ├── Data Systems/
│   ├── Machine Learning/
│   ├── Product Engineering/
│   ├── Tools & References/
│   ├── Writing & Ideas/
│   └── Personal/                    # visibility: private
├── Notes/                         # private study and working notes
├── Projects/
├── Writing/
│   └── Blogs/                     # private drafts; explicit public export
├── Quotes/
├── Daily/
├── Diary/                         # Yap voice entries; always private
├── Inbox/
├── Private/
├── Attachments/Captures/
├── Templates/
├── System/Bases/
└── Karage Work/                    # preserved; never exported
```

Every area has an area-map note named after the folder. The map, not each
capture, controls publication:

```yaml
---
kind: area
area_id: design-interaction
visibility: garden
site_slug: inspiration/design-interaction
media_policy: reference
---
```

`visibility: private` excludes the complete area even if a capture incorrectly
claims to be public. A new area must default to private until its map is
deliberately changed.

Garden Drop writes captures to:

```text
Areas/<Area>/Captures/<capture-id>.md
Attachments/Captures/<capture-id>/<filename>
```

## Blog links

Blog reading has its own garden area so it stays easy to find without mixing
long-form links into design or engineering captures:

```text
Areas/Blogs/Blogs.md
Areas/Blogs/Captures/<capture-id>.md
```

The area map is public (`visibility: garden`, `site_slug: inspiration/blogs`)
and each saved link is a normal `kind: capture` note. In Obsidian, create the
note from `Templates/Blog Link.md`, then put it in `Areas/Blogs/Captures/`.
Keep the canonical URL in the `source` field and repeat it as a Markdown link
under `## Source`; the exporter preserves both while adding the public
permalink and publication flags. `reading_status` can be `unread`, `reading`,
or `read` and is intentionally just lightweight personal metadata.

Example:

```yaml
---
id: gd-20260820-small-web
kind: capture
title: A small web worth returning to
source: https://example.com/a-small-web
source_type: web
captured_at: 2026-08-20T23:00:00+03:00
area: "[[Blogs]]"
tags:
  - capture
  - blog
metadata_status: complete
reading_status: unread
attachments: []
---

## Why I saved it

The author makes a careful argument about designing for attention.

## Source

[Open original](https://example.com/a-small-web)
```

Garden Drop can use this vault through its Settings vault picker, which stores a
security-scoped bookmark for future launches. For headless/local testing,
`GARDEN_DROP_VAULT` remains supported. Without either configuration, the app
writes to a temporary fixture vault.

## Public export

The private vault is never copied into the public repository. The exporter is
invoked explicitly:

```bash
npm run garden:export -- \
  --vault "/Users/shariq/Documents/Obsidian Vault" \
  --output "/path/to/quartz/content/garden-sync"
```

Only area maps marked `visibility: garden` and their captures are considered.
Generated pages receive `publish: true`; private wikilinks are replaced; source
media is omitted unless the area declares `media_policy: owned`; and contact,
résumé, credential, or secret-like content aborts the export.

The exporter owns only `content/garden-sync/`. Its manifest records generated
files. On a later run it deletes only files named by the previous manifest and
preserves untracked/handmade files. Validation happens in a staging directory,
so a failed export does not mutate the current public output.

Personal writing has a separate, opt-in bridge:

```bash
npm run writing:export -- \
  --vault "/Users/shariq/Documents/Obsidian Vault" \
  --output "./content/notes"
```

It reads only `Writing/` and exports only notes with `kind: writing`,
`visibility: public`, and `draft: false`. `Diary/`, `Daily/`, `Notes/`,
`Private/`, `Karage Work/`, and private `Writing/` drafts remain outside the
public repository.

## Link storage

External links remain ordinary Markdown links:

```markdown
[Open original](https://example.com)
```

Internal relationships remain Obsidian wikilinks:

```markdown
[[Areas/Design & Interaction/Design & Interaction]]
[[Notes/A useful note|A useful note]]
```

Attachments remain vault-relative Obsidian links under
`Attachments/Captures/`. The exporter rewrites and copies them only when the
area's media policy is `owned`.
