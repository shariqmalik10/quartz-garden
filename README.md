# Shariq Malik's personal site

A connected portfolio and technical fieldbook built with [Quartz 5](https://quartz.jzhao.xyz).

## Local development

Quartz requires Node.js 22+ and npm 10.9.2+.

```bash
npm ci
npx quartz plugin install
npx quartz build --serve
```

Content lives in [`content/`](content). Site configuration is in [`quartz.config.yaml`](quartz.config.yaml), and the custom visual layer is in [`quartz/styles/custom.scss`](quartz/styles/custom.scss).

## Obsidian publishing

The canonical private vault is `/Users/shariq/Documents/Obsidian Vault`.
Publishing is explicitly allowlisted by content type:

```bash
npm run writing:export -- --vault "/Users/shariq/Documents/Obsidian Vault" --output "./content/notes"
npm run quotes:export -- --vault "/Users/shariq/Documents/Obsidian Vault" --output "./content/quotes"
npm run garden:export -- --vault "/Users/shariq/Documents/Obsidian Vault" --output "./content/garden-sync"
```

Private diary logs are never exported. Writing requires `visibility: public`
and `draft: false`; quotes require `publish: true`; inspiration areas require
their area map to set `visibility: garden`. See
[`docs/writing-and-notes.md`](docs/writing-and-notes.md) and
[`docs/vault-structure.md`](docs/vault-structure.md).

## Production

Vercel builds with:

```bash
npx quartz plugin install && npx quartz build
```

The static output is emitted to `public/`.

## Credits

Built on Quartz by Jacky Zhao and its community contributors. Quartz is MIT licensed; see [`LICENSE.txt`](LICENSE.txt).
