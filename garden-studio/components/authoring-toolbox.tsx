"use client"

import { useEffect, useMemo, useRef, useState } from "react"

import { MARKDOWN_COMMANDS, WRITING_TEMPLATES } from "@/lib/editor-tools"

export type VaultLinkTarget = { title: string; path: string }

export function AuthoringToolbox({
  isNewWriting,
  linkTargets,
  currentWikilink,
  onCommand,
  onTemplate,
  onInsertWikilink,
}: {
  isNewWriting: boolean
  linkTargets: VaultLinkTarget[]
  currentWikilink?: string
  onCommand: (id: string) => void
  onTemplate: (id: string) => void
  onInsertWikilink: (path: string) => void
}) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState("")
  const [template, setTemplate] = useState(WRITING_TEMPLATES[0].id)
  const [target, setTarget] = useState(linkTargets[0]?.path || "")
  const [copied, setCopied] = useState(false)
  const searchRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const shortcut = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        setOpen((current) => !current)
      } else if (event.key === "Escape") {
        setOpen(false)
      }
    }
    window.addEventListener("keydown", shortcut)
    return () => window.removeEventListener("keydown", shortcut)
  }, [])

  useEffect(() => {
    if (open) requestAnimationFrame(() => searchRef.current?.focus())
  }, [open])

  const matches = useMemo(() => {
    const needle = query.trim().toLowerCase()
    if (!needle) return MARKDOWN_COMMANDS
    return MARKDOWN_COMMANDS.filter((command) =>
      `${command.label} ${command.group}`.toLowerCase().includes(needle),
    )
  }, [query])

  async function copyWikilink() {
    if (!currentWikilink) return
    await navigator.clipboard.writeText(currentWikilink)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1600)
  }

  return (
    <div className="authoring-toolbox">
      <div className="authoring-shortcuts">
        <button type="button" onClick={() => setOpen(true)} aria-haspopup="dialog">
          All commands <kbd>⌘ K</kbd>
        </button>
        {isNewWriting && (
          <div className="inline-tool">
            <label htmlFor="writing-template">Start from</label>
            <select
              id="writing-template"
              value={template}
              onChange={(event) => setTemplate(event.target.value)}
            >
              {WRITING_TEMPLATES.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.label}
                </option>
              ))}
            </select>
            <button type="button" onClick={() => onTemplate(template)}>
              Apply
            </button>
          </div>
        )}
        {linkTargets.length > 0 && (
          <div className="inline-tool vault-link-tool">
            <label htmlFor="vault-link-target">Link a note</label>
            <select
              id="vault-link-target"
              value={target}
              onChange={(event) => setTarget(event.target.value)}
            >
              {linkTargets.map((item) => (
                <option key={item.path} value={item.path}>
                  {item.title}
                </option>
              ))}
            </select>
            <button type="button" onClick={() => target && onInsertWikilink(target)}>
              Insert
            </button>
          </div>
        )}
        {currentWikilink && (
          <button type="button" onClick={() => void copyWikilink()} aria-live="polite">
            {copied ? "Wikilink copied" : "Copy this wikilink"}
          </button>
        )}
      </div>

      {open && (
        <section
          className="command-palette"
          role="dialog"
          aria-modal="false"
          aria-labelledby="command-heading"
        >
          <header>
            <div>
              <p id="command-heading">Insert into Markdown</p>
              <small>Search formatting, structure, and Obsidian commands.</small>
            </div>
            <button type="button" onClick={() => setOpen(false)} aria-label="Close commands">
              Esc
            </button>
          </header>
          <input
            ref={searchRef}
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search commands…"
            aria-label="Search editor commands"
          />
          <div className="command-results">
            {matches.length ? (
              matches.map((command) => (
                <button
                  type="button"
                  key={command.id}
                  onClick={() => {
                    onCommand(command.id)
                    setOpen(false)
                    setQuery("")
                  }}
                >
                  <strong>{command.label}</strong>
                  <small>{command.group}</small>
                  <span aria-hidden="true">↵</span>
                </button>
              ))
            ) : (
              <p>No command matches “{query}”.</p>
            )}
          </div>
        </section>
      )}
    </div>
  )
}
