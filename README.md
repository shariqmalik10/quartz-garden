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

The repository includes a selective Obsidian importer for notes, writings, quotes, and attachments:

```bash
cp .env.example .env
npm run vault:check
npm run vault:sync -- --dry-run
npm run vault:sync
```

See [`OBSIDIAN_SYNC.md`](OBSIDIAN_SYNC.md) for vault mappings, draft handling, live watching, daily quote properties, and publishing.

## Production

Vercel builds with:

```bash
npx quartz plugin install && npx quartz build
```

The static output is emitted to `public/`.

## Credits

Built on Quartz by Jacky Zhao and its community contributors. Quartz is MIT licensed; see [`LICENSE.txt`](LICENSE.txt).
