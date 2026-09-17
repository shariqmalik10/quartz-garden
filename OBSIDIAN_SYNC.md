# Obsidian → Quartz publishing

> **Legacy direct mirror:** this generic folder copier is currently inactive
> because no `OBSIDIAN_VAULT_PATH` is set in `.env`. It predates the canonical
> private-vault exporters and can copy drafts into the public repository. For
> the live workflow, use `writing:export`, `quotes:export`, and `garden:export`
> as documented in `docs/writing-and-notes.md` and `docs/vault-structure.md`.

The site is ready to import selected folders from an Obsidian vault without replacing the handcrafted homepage, project pages, or site configuration.

Quartz itself recommends Obsidian for authoring and supports wikilinks, callouts, embeds, properties, highlights, comments, task lists, Mermaid, and common attachments. This project already has Obsidian-flavoured Markdown enabled and uses `shortest` link resolution, matching Quartz’s recommended Obsidian setup.

## 1. Connect the vault

Copy the example environment file and update its one value:

```bash
cp .env.example .env
```

```dotenv
OBSIDIAN_VAULT_PATH=/absolute/path/to/Your Vault
```

`.env` is ignored by Git, so the local vault path is never published.

The default folder mapping is defined in [`obsidian-sync.config.json`](obsidian-sync.config.json):

| Vault folder   | Website destination        |
| -------------- | -------------------------- |
| `Notes/`       | `content/notes/`           |
| `Writings/`    | `content/writing/`         |
| `Quotes/`      | `content/quotes/`          |
| `Attachments/` | `content/assets/obsidian/` |

Change the `from` values later if your vault uses different folder names. Private, template, trash, Git, and Obsidian-settings folders are ignored. The importer never deletes website files and skips unchanged content.

## 2. Check and sync

```bash
npm run vault:check
npm run vault:sync -- --dry-run
npm run vault:sync
```

For a live local writing loop:

```bash
npm run vault:watch
```

The watcher waits for Obsidian to finish writing, then copies only changed files. In a second terminal, run `npm run dev` to preview the garden.

## 3. Keep drafts private

Add `draft: true` to any note that should remain in the vault but stay off the website:

```yaml
---
title: Private working note
draft: true
---
```

Quartz’s remove-draft filter is already enabled. When a note is ready, remove the field or set it to `false`.

## Daily quotes

Create one Markdown file inside the vault’s `Quotes/` folder. A ready-to-copy template lives at [`vault-templates/daily-quote.md`](vault-templates/daily-quote.md).

Recommended filename:

```text
2026-08-10-short-label.md
```

Required property:

```yaml
quote: "The line you want to keep."
```

Recommended properties are `author`, `source`, `sourceUrl`, `date`, and the `quote` tag. The homepage automatically displays the four newest quote files; `/quotes` remains the complete drawer.

## Publish

After syncing and reviewing locally:

```bash
npm run vault:sync
npm run check
node quartz/bootstrap-cli.mjs sync --message "publish notes from Obsidian"
```

Pushing to GitHub triggers the connected Vercel project. Jacky Zhao’s public garden follows the same essential model: publishable Markdown lives in the repository’s `content/` directory, while `.obsidian` and private material are excluded from Git.

If you later depend on Obsidian Dataview queries, install the optional **Quartz Syncer** Obsidian community plugin so those queries can be exported as static Markdown during sync.
