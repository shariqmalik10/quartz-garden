# Where to add content

Use this map when deciding where something belongs. Files under `content/`
become pages on the Quartz site; generated folders should be updated through
their source workflow instead of edited by hand.

| What you are adding                               | Source of truth                                                               | Where it appears                                   |
| ------------------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------- |
| Your writing, diary-like thoughts, or study notes | `content/notes/<short-title>.md`                                              | `/notes`, plus **Latest writing** on the home page |
| A quote                                           | `/Users/shariq/Documents/Obsidian Vault/Quotes/Entries/<date-and-title>.md`   | Home quote rail, quote drawer, and `/quotes`       |
| A link to someone else's blog                     | `/Users/shariq/Documents/Obsidian Vault/Areas/Blogs/Captures/<capture-id>.md` | `/inspiration/blogs`                               |
| Another saved inspiration link                    | `Obsidian Vault/Areas/<Area>/Captures/<capture-id>.md`                        | The matching `/inspiration/<area>` page            |
| A link in the large Signal Atlas collection       | `signal-atlas/src/data/atlas.ts`                                              | The grouped collection at `/inspiration`           |
| A project or case study                           | `content/projects/<project-name>.md`                                          | `/projects`                                        |
| A current-status update                           | `content/now.md`                                                              | `/now`                                             |
| Your biography                                    | `content/about.md`                                                            | `/about`                                           |
| An area overview                                  | `content/areas/<area-name>.md`                                                | `/areas/<area-name>`                               |
| Home-page copy                                    | `content/index.md`                                                            | `/`                                                |

## Your writing, diary entries, and study notes

Start from `content/templates/writing-note.md`. Use a short kebab-case filename,
for example `content/notes/learning-postgres-indexes.md`.

To publish it, set:

```yaml
kind: writing
visibility: public
draft: false
```

Public entries are added automatically to the Writing & Notes page and to the
Latest writing list. Both lists sort by the frontmatter `date`, newest first.
There is no numbering on the site, and the date is shown under each title.

For a private or unfinished entry, use:

```yaml
kind: writing
visibility: private
draft: true
```

Quartz excludes drafts from the built site. A public Git repository still
exposes committed source files, even when Quartz does not render them, so truly
private writing must remain outside this repository. Keep private essay or
diary drafts in `Obsidian Vault/Writing/`, and private study notes in
`Obsidian Vault/Notes/`. Copy them into `content/notes/` only when they are
ready to publish.

## Quotes

In Obsidian, copy `Templates/Quote.md` into `Quotes/Entries/`. Fill in the quote
and any known attribution:

```yaml
kind: quote
quote: "The line you want to keep."
author: "Author name"
source: "Book, film, or article"
sourceUrl: "https://example.com"
captured_at: 2026-08-23T10:00:00+03:00
publish: true
```

`publish: false` keeps the quote out of the site. When the public quotes are
ready, export them from the project root:

```bash
npm run quotes:export -- \
  --vault "/Users/shariq/Documents/Obsidian Vault" \
  --output "./content/quotes"
```

Do not hand-edit `content/quotes/`; the quote exporter owns that directory.

## Links and inspiration

For an individual blog link, use `Obsidian Vault/Templates/Blog Link.md` and
save the copy in `Areas/Blogs/Captures/`. For design, data, machine-learning,
product-engineering, or tool references, use `Templates/Capture.md` and save it
under the matching area's `Captures/` folder.

Export those captures with:

```bash
npm run garden:export -- \
  --vault "/Users/shariq/Documents/Obsidian Vault" \
  --output "./content/garden-sync"
```

The exporter owns `content/garden-sync/`. For the larger Signal Atlas list,
edit `src/data/atlas.ts` in the `signal-atlas` repository and then run
`npm run links:sync` here. That command regenerates
`content/inspiration/index.md`.

## Direct site pages

Projects, the Now page, the About page, area overviews, and home-page copy are
ordinary Markdown files in the paths shown in the table. Their frontmatter
provides the title and description; the Markdown body is the visible page.
