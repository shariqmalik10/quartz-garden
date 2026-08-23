# Adding writing and diary notes

Shariq's own writing lives in `content/notes/`. Links collected from other
people live separately under `content/garden-sync/inspiration/` and on the
generated `/inspiration` page.

Start by copying `content/templates/writing-note.md` somewhere outside the
repository for a genuinely private draft. When an entry is ready for the site,
move the copy into `content/notes/`, give it a short kebab-case filename, and
change its publication fields:

```yaml
kind: writing
visibility: public
draft: false
```

Public entries are added automatically to the Writing & Notes page and to the
Latest writing list below the site name. Both lists sort by the frontmatter
`date`, newest first. There is no numbering on the site, and the date is shown
under each title in the sidebar.

For a private or unfinished entry, use:

```yaml
kind: writing
visibility: private
draft: true
```

Quartz excludes drafts from the built site. A public Git repository still
exposes committed source files, even when Quartz does not render them, so truly
private writing must remain outside this repository until it is ready to
publish.
