# Content contracts and migration

Garden Studio, the private-vault workflow, and the Quartz exporters share one
versioned content contract. The current version is `1` and is implemented in
[`scripts/publishing/contracts.mjs`](../scripts/publishing/contracts.mjs).

The contract is deliberately compatible with the existing vault. Managed files
now carry `contract_version: 1`; the validators temporarily accept an absent
version so an older local note can be diagnosed and migrated instead of becoming
unreadable.

## Collection registry

| Contract           | Source                       | Publication condition                   | Public owner           |
| ------------------ | ---------------------------- | --------------------------------------- | ---------------------- |
| `area`             | `Areas/<Area>/<Area>.md`     | `visibility: garden`                    | `content/garden-sync/` |
| `capture`          | `Areas/<Area>/Captures/*.md` | parent area is public                   | `content/garden-sync/` |
| `quote-collection` | `Quotes/Quotes.md`           | `visibility: garden`                    | `content/quotes/`      |
| `quote`            | `Quotes/Entries/*.md`        | `publish: true`                         | `content/quotes/`      |
| `writing`          | `Writing/**/*.md`            | `visibility: public` and `draft: false` | `content/notes/`       |

Private areas, unpublished quotes, private writing, drafts, and non-managed map
notes remain in the vault and are reported as skipped. An incomplete private
draft does not block another collection from publishing.

## Version-one required fields

### Area

```yaml
contract_version: 1
kind: area
visibility: garden # garden or private
site_slug: inspiration/design
media_policy: reference # reference or owned; optional
```

`site_slug` must be a relative path without empty, absolute, or `..` segments.

### Capture

```yaml
contract_version: 1
id: gd-20260919-example
kind: capture
title: Example
source: https://example.com # optional, but HTTP(S) when present
```

`id` contains only letters, numbers, and hyphens. IDs must be unique within the
same public area because they become filenames.

### Quote

```yaml
contract_version: 1
kind: quote
quote: A line worth keeping.
publish: false
```

The quote collection map has `kind: quote-collection` and a `garden` or
`private` visibility.

### Writing

```yaml
contract_version: 1
kind: writing
title: A clear title
date: 2026-09-19
visibility: private
draft: true
```

Public writing slugs must be unique and cannot resolve to the reserved
`index.md` page.

## Publication report

Run the non-mutating audit and exporter preflight:

```bash
npm run publish:check -- \
  --vault "/Users/shariq/Documents/Obsidian Vault" \
  --site "."
```

Every discovered file receives one status:

- `included`: it will cross the public boundary, with its generated target;
- `skipped`: it stays private or is not a managed content note;
- `blocked`: its schema, path, safety policy, or unique target is invalid.

The command exits unsuccessfully when any record is blocked. `--json` returns
the same records and stable error codes for Garden Studio to consume later.

## Migration

Preview changes first:

```bash
npm run publish:migrate -- --vault "/path/to/vault"
```

The preview never writes. It currently understands:

- adding `contract_version: 1` to managed content;
- converting a legacy writing `published` flag into `visibility` and `draft`;
- copying a legacy quote `date` into `captured_at` when needed.

Apply an inspected report only in a clean, dedicated vault branch:

```bash
npm run publish:migrate -- --vault "/path/to/vault" --write
```

After a migration, rerun `publish:migrate` without `--write`; it should report
zero pending files. Then run `publish:check` before committing.

## Error shape

Contract errors have stable fields for command-line tools and the future CMS:

```json
{
  "name": "ContentContractError",
  "code": "schema_invalid",
  "collection": "writing",
  "path": "Writing/example.md",
  "message": "Writing/example.md does not match writing v1: date is required",
  "details": [{ "field": "date", "code": "required", "message": "is required" }]
}
```

Human-readable text may improve over time; `code`, `collection`, `path`, and the
field-level detail codes are the stable integration surface.
