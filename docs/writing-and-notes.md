# Where to add content

Use this map when deciding where something belongs. Files under `content/`
become pages on the Quartz site; generated folders should be updated through
their source workflow instead of edited by hand.

| What you are adding                         | Source of truth                                                               | Where it appears                             |
| ------------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------- |
| Your private daily transcription            | `/Users/shariq/Documents/Obsidian Vault/Diary/diary-log_<date>.md`            | Private; never exported                      |
| Your blog drafts and publishable writing    | `/Users/shariq/Documents/Obsidian Vault/Writing/Blogs/<short-title>.md`       | `/notes` only after explicit public export   |
| Your private study and working notes        | `/Users/shariq/Documents/Obsidian Vault/Notes/<short-title>.md`               | Private; never exported automatically        |
| A quote                                     | `/Users/shariq/Documents/Obsidian Vault/Quotes/Entries/<date-and-title>.md`   | Home quote rail, quote drawer, and `/quotes` |
| A link to someone else's blog               | `/Users/shariq/Documents/Obsidian Vault/Areas/Blogs/Captures/<capture-id>.md` | `/inspiration/blogs`                         |
| Another saved inspiration link              | `Obsidian Vault/Areas/<Area>/Captures/<capture-id>.md`                        | The matching `/inspiration/<area>` page      |
| A link in the large Signal Atlas collection | `signal-atlas/src/data/atlas.ts`                                              | The grouped collection at `/inspiration`     |
| A project or case study                     | `content/projects/<project-name>.md`                                          | `/projects`                                  |
| A current-status update                     | `content/now.md`                                                              | `/now`                                       |
| Your biography                              | `content/about.md`                                                            | `/about`                                     |
| An area overview                            | `content/areas/<area-name>.md`                                                | `/areas/<area-name>`                         |
| Home-page copy                              | `content/index.md`                                                            | `/`                                          |

## Your writing, diary entries, and study notes

The standalone Yap app is the shortest path:

1. Choose **Resume / switch → Blog → New blog draft…**.
2. Name the file; the app creates it under `Obsidian Vault/Writing/Blogs/` with
   `visibility: private` and `draft: true`.
3. Speak or type into it. The app appends and never replaces existing text.
4. Later, pick it under **Recent**, or choose **Continue existing file…**.
5. Choose **Open in Obsidian** after a save to jump to that exact entry.

For a private study note, choose **Notes** instead. To resume any other Markdown
file in the vault, choose **Any file → Select any Markdown file…**. New folder +
file creates one folder below the selected workspace and then asks for its first
Markdown filename.

You can also create the Markdown file yourself using
`content/templates/writing-note.md` as the metadata reference. Use a short
kebab-case filename such as `learning-postgres-indexes.md`.

To publish it, set:

```yaml
kind: writing
visibility: public
draft: false
```

Then export from the repository root:

```bash
npm run writing:export -- \
  --vault "/Users/shariq/Documents/Obsidian Vault" \
  --output "./content/notes"
```

Only files with both public settings cross into the repository. Public entries
are added automatically to the Writing & Notes page and to the Latest writing
list. Both lists sort by the frontmatter `date`, newest first. There is no
numbering on the site, and the date is shown under each title.

For a private or unfinished entry, use:

```yaml
kind: writing
visibility: private
draft: true
```

The writing exporter skips these files entirely, so private drafts never enter
the public repository. Daily captures under `Diary/`, private study notes under
`Notes/`, and anything under `Private/` are not inputs to this exporter.

The exporter owns only its manifest-listed files inside `content/notes/`. It
refuses to replace handmade notes such as `content/notes/index.md` and removes
only stale files that it generated previously.

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
