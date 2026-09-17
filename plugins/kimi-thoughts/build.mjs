import fs from "node:fs/promises"
import path from "node:path"
import { build } from "esbuild"
import { format, resolveConfig } from "prettier"

const root = import.meta.dirname

const shared = {
  bundle: true,
  format: "esm",
  platform: "node",
  target: "esnext",
  external: ["preact", "@quartz-community/types"],
  logLevel: "info",
}

const outputs = [
  { entry: path.join(root, "src/index.ts"), outfile: path.join(root, "dist/index.js") },
  {
    entry: path.join(root, "src/components/index.ts"),
    outfile: path.join(root, "dist/components/index.js"),
  },
]

for (const { entry, outfile } of outputs) {
  await build({ ...shared, entryPoints: [entry], outfile })
}

// keep the committed dist aligned with the repository's prettier config
for (const { outfile } of outputs) {
  const config = await resolveConfig(outfile)
  const source = await fs.readFile(outfile, "utf8")
  const formatted = await format(source, { ...config, filepath: outfile })
  await fs.writeFile(outfile, formatted)
}
