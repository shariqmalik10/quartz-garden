import { createHash } from "node:crypto"
import { existsSync } from "node:fs"
import { copyFile, mkdir, readFile, readdir, stat } from "node:fs/promises"
import { homedir } from "node:os"
import path from "node:path"
import { watch } from "chokidar"

const projectRoot = path.resolve(import.meta.dirname, "..")
const contentRoot = path.join(projectRoot, "content")
const configPath = path.join(projectRoot, "obsidian-sync.config.json")
const envPath = path.join(projectRoot, ".env")

if (existsSync(envPath)) {
  const envText = await readFile(envPath, "utf8")
  for (const line of envText.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith("#")) continue
    const separator = trimmed.indexOf("=")
    if (separator < 1) continue
    const key = trimmed.slice(0, separator).trim()
    const rawValue = trimmed.slice(separator + 1).trim()
    const value = rawValue.replace(/^(["'])(.*)\1$/, "$2")
    if (process.env[key] === undefined) process.env[key] = value
  }
}

const args = process.argv.slice(2)
const flag = (name) => args.includes(name)
const valueAfter = (name) => {
  const index = args.indexOf(name)
  return index >= 0 ? args[index + 1] : undefined
}

const expandHome = (value) =>
  value?.startsWith("~/") ? path.join(homedir(), value.slice(2)) : value

const vaultValue = expandHome(valueAfter("--vault") ?? process.env.OBSIDIAN_VAULT_PATH)
const checkOnly = flag("--check")
const dryRun = flag("--dry-run")
const watchMode = flag("--watch")

const config = JSON.parse(await readFile(configPath, "utf8"))

const inside = (parent, child) => {
  const relative = path.relative(parent, child)
  return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative)
}

const validateRelativePath = (value, label) => {
  if (!value || path.isAbsolute(value) || value.split(/[\\/]/).includes("..")) {
    throw new Error(`${label} must be a safe path relative to its root: ${value}`)
  }
}

for (const mapping of config.mappings) {
  validateRelativePath(mapping.from, "mapping.from")
  validateRelativePath(mapping.to, "mapping.to")
  const target = path.resolve(contentRoot, mapping.to)
  if (!inside(contentRoot, target)) throw new Error(`Mapping escapes content/: ${mapping.to}`)
}

if (!vaultValue) {
  if (checkOnly) {
    console.log("Obsidian sync is configured and waiting for OBSIDIAN_VAULT_PATH in .env.")
    process.exit(0)
  }
  throw new Error("Set OBSIDIAN_VAULT_PATH in .env or pass --vault /absolute/path/to/your/vault.")
}

const vaultRoot = path.resolve(vaultValue)
if (!existsSync(vaultRoot) || !(await stat(vaultRoot)).isDirectory()) {
  throw new Error(`Obsidian vault directory was not found: ${vaultRoot}`)
}

const ignoredNames = new Set(config.ignore)
const extensionSet = (mapping) => new Set(mapping.extensions.map((item) => item.toLowerCase()))
const digest = (buffer) => createHash("sha256").update(buffer).digest("hex")

async function collectFiles(root, allowedExtensions, relative = "") {
  const directory = path.join(root, relative)
  if (!existsSync(directory)) return []
  const entries = await readdir(directory, { withFileTypes: true })
  const files = []

  for (const entry of entries) {
    if (ignoredNames.has(entry.name) || entry.name.startsWith(".")) continue
    const nextRelative = path.join(relative, entry.name)
    if (entry.isSymbolicLink()) continue
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(root, allowedExtensions, nextRelative)))
      continue
    }
    if (!entry.isFile() || !allowedExtensions.has(path.extname(entry.name).toLowerCase())) continue
    files.push(nextRelative)
  }

  return files
}

async function syncVault() {
  const summary = { copied: 0, unchanged: 0, missingMappings: 0 }

  for (const mapping of config.mappings) {
    const sourceRoot = path.resolve(vaultRoot, mapping.from)
    const targetRoot = path.resolve(contentRoot, mapping.to)
    if (!inside(vaultRoot, sourceRoot)) throw new Error(`Mapping escapes vault: ${mapping.from}`)

    if (!existsSync(sourceRoot)) {
      summary.missingMappings += 1
      console.warn(`skip  ${mapping.from}/ (folder not present yet)`)
      continue
    }

    const files = await collectFiles(sourceRoot, extensionSet(mapping))
    for (const relative of files) {
      const source = path.join(sourceRoot, relative)
      const target = path.join(targetRoot, relative)
      const sourceBuffer = await readFile(source)
      const unchanged =
        existsSync(target) && digest(await readFile(target)) === digest(sourceBuffer)

      if (unchanged) {
        summary.unchanged += 1
        continue
      }

      console.log(
        `${dryRun ? "would copy" : "copy "} ${mapping.from}/${relative} → content/${mapping.to}/${relative}`,
      )
      if (!dryRun) {
        await mkdir(path.dirname(target), { recursive: true })
        await copyFile(source, target)
      }
      summary.copied += 1
    }
  }

  console.log(
    `${dryRun ? "Dry run" : "Sync complete"}: ${summary.copied} copied, ${summary.unchanged} unchanged, ${summary.missingMappings} source folders waiting.`,
  )
}

if (checkOnly) {
  console.log(`Vault found: ${vaultRoot}`)
  for (const mapping of config.mappings) {
    const present = existsSync(path.join(vaultRoot, mapping.from))
    console.log(`${present ? "ready" : "waiting"}  ${mapping.from}/ → content/${mapping.to}/`)
  }
  process.exit(0)
}

await syncVault()

if (watchMode) {
  const roots = config.mappings
    .map((mapping) => path.join(vaultRoot, mapping.from))
    .filter((source) => existsSync(source))
  if (roots.length === 0) throw new Error("None of the configured vault folders exist yet.")

  let timer
  const watcher = watch(roots, {
    ignored: (watchedPath) =>
      watchedPath
        .split(path.sep)
        .some((part) => ignoredNames.has(part) || (part.startsWith(".") && part !== ".")),
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 220, pollInterval: 70 },
  })

  watcher.on("all", () => {
    clearTimeout(timer)
    timer = setTimeout(() => void syncVault(), 300)
  })
  console.log("Watching the configured vault folders. Press Ctrl+C to stop.")
}
