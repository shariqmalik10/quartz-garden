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
│   ├── Data Systems/
│   ├── Machine Learning/
│   ├── Product Engineering/
│   ├── Tools & References/
│   ├── Writing & Ideas/
│   └── Personal/                    # visibility: private
├── Notes/
├── Projects/
├── Writing/
├── Quotes/
├── Daily/
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

Garden Drop must use this vault through `GARDEN_DROP_VAULT` until its persistent
security-scoped vault picker is implemented. Without that setting, the current
app writes to a temporary fixture vault.

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
