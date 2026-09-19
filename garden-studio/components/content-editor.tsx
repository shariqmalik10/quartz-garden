"use client"

import { useDeferredValue, useEffect, useRef, useState } from "react"
import { useRouter } from "next/navigation"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

import { serializeFields, slugify, validateFields, type EditorFields } from "@/lib/content"

type SaveState = "idle" | "dirty" | "saving" | "saved" | "error"
type EditorMode = "write" | "split" | "preview"

type SaveResponse = {
  ok: boolean
  message: string
  path?: string
  revision?: string
  demo?: boolean
  code?: string
  details?: unknown
}

const tools = [
  ["Heading", "## ", ""],
  ["Bold", "**", "**"],
  ["Italic", "_", "_"],
  ["Link", "[", "](https://)"],
  ["Quote", "> ", ""],
  ["Bullets", "- ", ""],
  ["Code", "`", "`"],
  ["Wikilink", "[[", "]]"],
] as const

function labelFor(collection: EditorFields["collection"]) {
  return collection === "writing" ? "writing" : collection === "quotes" ? "quote" : "saved link"
}

export function ContentEditor({
  initialFields,
  originalPath,
  initialRevision,
  areas,
  demo,
  obsidianUri,
}: {
  initialFields: EditorFields
  originalPath?: string
  initialRevision?: string
  areas: string[]
  demo: boolean
  obsidianUri?: string
}) {
  const router = useRouter()
  const [fields, setFields] = useState(initialFields)
  const [revision, setRevision] = useState(initialRevision)
  const [filePath, setFilePath] = useState(originalPath)
  const [mode, setMode] = useState<EditorMode>("split")
  const [saveState, setSaveState] = useState<SaveState>("idle")
  const [notice, setNotice] = useState(demo ? "Preview mode keeps drafts in this browser." : "")
  const [serverIssues, setServerIssues] = useState<Array<{ field: string; message: string }>>([])
  const [conflict, setConflict] = useState<{ sha: string; content: string } | null>(null)
  const [slugTouched, setSlugTouched] = useState(Boolean(initialFields.slug))
  const editorRef = useRef<HTMLTextAreaElement>(null)
  const deferredBody = useDeferredValue(fields.body)
  const draftKey = `garden-studio:draft:${originalPath || initialFields.collection}`

  useEffect(() => {
    const stored = window.localStorage.getItem(draftKey)
    if (!stored) return
    try {
      const draft = JSON.parse(stored) as { fields: EditorFields; savedAt: string }
      if (
        window.confirm(
          `Restore the browser draft saved ${new Date(draft.savedAt).toLocaleString()}?`,
        )
      ) {
        setFields(draft.fields)
        setSaveState("dirty")
      }
    } catch {
      window.localStorage.removeItem(draftKey)
    }
    // Draft restoration intentionally happens only when this editor opens.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (saveState !== "dirty") return
    const timeout = window.setTimeout(() => {
      window.localStorage.setItem(
        draftKey,
        JSON.stringify({ fields, savedAt: new Date().toISOString() }),
      )
    }, 450)
    return () => window.clearTimeout(timeout)
  }, [draftKey, fields, saveState])

  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => {
      if (saveState !== "dirty") return
      event.preventDefault()
    }
    window.addEventListener("beforeunload", warn)
    return () => window.removeEventListener("beforeunload", warn)
  }, [saveState])

  useEffect(() => {
    const shortcut = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "s") {
        event.preventDefault()
        void save("draft")
      }
    }
    window.addEventListener("keydown", shortcut)
    return () => window.removeEventListener("keydown", shortcut)
  })

  function update<K extends keyof EditorFields>(key: K, value: EditorFields[K]) {
    setFields((current) => ({ ...current, [key]: value }))
    setSaveState("dirty")
    setNotice("")
    setServerIssues([])
  }

  function updateTitle(title: string) {
    setFields((current) => ({
      ...current,
      title,
      ...(!slugTouched ? { slug: slugify(title) } : {}),
    }))
    setSaveState("dirty")
  }

  function insert(prefix: string, suffix: string) {
    const textarea = editorRef.current
    if (!textarea) return
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const selected = fields.body.slice(start, end)
    const next = `${fields.body.slice(0, start)}${prefix}${selected}${suffix}${fields.body.slice(end)}`
    update("body", next)
    requestAnimationFrame(() => {
      textarea.focus()
      textarea.setSelectionRange(start + prefix.length, end + prefix.length)
    })
  }

  async function save(intent: "draft" | "ready") {
    const issues = validateFields(fields)
    if (issues.length) {
      setServerIssues(issues)
      setNotice("Fix the highlighted fields before saving.")
      setSaveState("error")
      document.querySelector<HTMLElement>(`[data-field="${issues[0].field}"]`)?.focus()
      return
    }
    setSaveState("saving")
    setNotice(
      intent === "ready"
        ? "Checking and marking this entry ready…"
        : "Saving to the private vault…",
    )
    const response = await fetch("/api/content/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fields, originalPath: filePath, expectedRevision: revision, intent }),
    })
    const result = (await response.json()) as SaveResponse
    if (!response.ok) {
      setSaveState("error")
      setNotice(result.message)
      if (result.code === "schema_invalid" && Array.isArray(result.details)) {
        setServerIssues(result.details as Array<{ field: string; message: string }>)
      }
      if (result.code === "edit_conflict" && result.details && typeof result.details === "object") {
        setConflict(result.details as { sha: string; content: string })
      }
      return
    }
    if (intent === "ready") {
      setFields((current) => ({
        ...current,
        ...(current.collection === "writing" ? { visibility: "public", draft: false } : {}),
        ...(current.collection === "quotes" ? { publish: true } : {}),
      }))
    }
    setFilePath(result.path)
    setRevision(result.revision)
    setSaveState("saved")
    setNotice(result.message)
    setConflict(null)
    window.localStorage.removeItem(draftKey)
    if (!result.demo) router.replace(`/edit?path=${encodeURIComponent(result.path || "")}`)
    router.refresh()
  }

  const issueFor = (field: keyof EditorFields) =>
    serverIssues.find((issue) => issue.field === field)?.message

  return (
    <div className="editor-workspace">
      <header className="editor-commandbar">
        <div className="save-indicator" aria-live="polite">
          <span className={`save-dot ${saveState}`} aria-hidden="true" />
          <strong>
            {saveState === "dirty"
              ? "Unsaved changes"
              : saveState === "saving"
                ? "Saving…"
                : saveState === "saved"
                  ? "Saved"
                  : saveState === "error"
                    ? "Needs attention"
                    : "Ready"}
          </strong>
          {notice && <small>{notice}</small>}
        </div>
        <div className="editor-actions">
          {obsidianUri && (
            <a className="secondary-button" href={obsidianUri}>
              Open in Obsidian <span aria-hidden="true">↗</span>
            </a>
          )}
          <button
            className="secondary-button"
            type="button"
            onClick={() => void save("draft")}
            disabled={saveState === "saving"}
          >
            Save draft
          </button>
          <button
            className="primary-button"
            type="button"
            onClick={() => void save("ready")}
            disabled={saveState === "saving"}
          >
            Save &amp; mark ready
          </button>
        </div>
      </header>

      {conflict && (
        <section className="conflict-panel" aria-labelledby="conflict-heading">
          <div>
            <p className="eyebrow">Concurrent edit</p>
            <h2 id="conflict-heading">Obsidian or another session changed this file.</h2>
            <p>
              Your browser draft is safe. Compare the latest file, then explicitly retry if your
              version should win.
            </p>
          </div>
          <details>
            <summary>Show latest vault version</summary>
            <pre>{conflict.content}</pre>
          </details>
          <button
            type="button"
            onClick={() => {
              setRevision(conflict.sha)
              setConflict(null)
              setSaveState("dirty")
              setNotice("Latest revision acknowledged. Save again to keep your draft.")
            }}
          >
            Keep my draft and retry
          </button>
        </section>
      )}

      <div className="editor-layout">
        <aside className="editor-fields" aria-label="Entry properties">
          <div className="field-group">
            <p className="eyebrow">
              {filePath ? "Edit" : "New"} {labelFor(fields.collection)}
            </p>
            {fields.collection !== "quotes" && (
              <Field label="Title" field="title" issue={issueFor("title")}>
                <input
                  data-field="title"
                  value={fields.title}
                  onChange={(event) => updateTitle(event.target.value)}
                />
              </Field>
            )}
            {fields.collection === "quotes" && (
              <Field label="Quote" field="quote" issue={issueFor("quote")}>
                <textarea
                  data-field="quote"
                  rows={6}
                  value={fields.quote}
                  onChange={(event) => {
                    update("quote", event.target.value)
                    if (!slugTouched) update("slug", slugify(event.target.value.slice(0, 60)))
                  }}
                />
              </Field>
            )}
            <Field
              label="Slug"
              field="slug"
              issue={issueFor("slug")}
              hint={
                filePath
                  ? "Changing the slug updates metadata, not the existing filename."
                  : "Used for the Markdown filename."
              }
            >
              <input
                data-field="slug"
                value={fields.slug}
                onChange={(event) => {
                  setSlugTouched(true)
                  update("slug", slugify(event.target.value))
                }}
              />
            </Field>
          </div>

          {fields.collection === "writing" && (
            <div className="field-group">
              <Field label="Summary" field="description">
                <textarea
                  rows={3}
                  value={fields.description}
                  onChange={(event) => update("description", event.target.value)}
                />
              </Field>
              <Field label="Date" field="date" issue={issueFor("date")}>
                <input
                  data-field="date"
                  type="date"
                  value={fields.date}
                  onChange={(event) => update("date", event.target.value)}
                />
              </Field>
              <div className="field-pair">
                <Field label="Visibility" field="visibility">
                  <select
                    value={fields.visibility}
                    onChange={(event) =>
                      update("visibility", event.target.value as "public" | "private")
                    }
                  >
                    <option value="private">Private</option>
                    <option value="public">Public</option>
                  </select>
                </Field>
                <label className="check-field">
                  <input
                    type="checkbox"
                    checked={fields.draft}
                    onChange={(event) => update("draft", event.target.checked)}
                  />{" "}
                  Keep as draft
                </label>
              </div>
            </div>
          )}

          {fields.collection === "quotes" && (
            <div className="field-group">
              <Field label="Author" field="author">
                <input
                  value={fields.author}
                  onChange={(event) => update("author", event.target.value)}
                />
              </Field>
              <Field label="Source" field="sourceName">
                <input
                  value={fields.sourceName}
                  onChange={(event) => update("sourceName", event.target.value)}
                />
              </Field>
              <Field label="Source URL" field="sourceUrl" issue={issueFor("sourceUrl")}>
                <input
                  data-field="sourceUrl"
                  type="url"
                  value={fields.sourceUrl}
                  onChange={(event) => update("sourceUrl", event.target.value)}
                />
              </Field>
              <label className="check-field">
                <input
                  type="checkbox"
                  checked={fields.publish}
                  onChange={(event) => update("publish", event.target.checked)}
                />{" "}
                Ready for the quotes page
              </label>
            </div>
          )}

          {fields.collection === "links" && (
            <div className="field-group">
              <Field label="Original URL" field="sourceUrl" issue={issueFor("sourceUrl")}>
                <input
                  data-field="sourceUrl"
                  type="url"
                  placeholder="https://"
                  value={fields.sourceUrl}
                  onChange={(event) => update("sourceUrl", event.target.value)}
                />
              </Field>
              <Field label="Obsidian area" field="area" issue={issueFor("area")}>
                <select
                  data-field="area"
                  value={fields.area}
                  onChange={(event) => update("area", event.target.value)}
                >
                  {areas.map((area) => (
                    <option key={area}>{area}</option>
                  ))}
                </select>
              </Field>
              <Field label="Metadata" field="metadataStatus">
                <select
                  value={fields.metadataStatus}
                  onChange={(event) =>
                    update("metadataStatus", event.target.value as EditorFields["metadataStatus"])
                  }
                >
                  <option value="complete">Complete</option>
                  <option value="partial">Partial</option>
                  <option value="pending">Pending</option>
                </select>
              </Field>
            </div>
          )}

          <div className="field-group">
            <Field label="Tags" field="tags" hint="Comma-separated; # is optional.">
              <input
                value={fields.tags.join(", ")}
                onChange={(event) => update("tags", event.target.value.split(","))}
              />
            </Field>
            <details className="advanced-fields">
              <summary>Advanced file details</summary>
              <dl>
                <div>
                  <dt>Vault path</dt>
                  <dd>{filePath || "Created after the first save"}</dd>
                </div>
                <div>
                  <dt>Revision</dt>
                  <dd>{revision?.slice(0, 12) || "New file"}</dd>
                </div>
                <div>
                  <dt>Contract</dt>
                  <dd>v1 · {fields.collection}</dd>
                </div>
              </dl>
              <textarea
                aria-label="Generated Markdown file"
                readOnly
                value={serializeFields(fields, filePath)}
                rows={10}
              />
            </details>
          </div>
        </aside>

        <section className="editor-document" aria-label="Markdown editor">
          <div className="editor-tabs" role="group" aria-label="Editor view">
            <button
              className={mode === "write" ? "active" : ""}
              type="button"
              onClick={() => setMode("write")}
            >
              Write
            </button>
            <button
              className={mode === "split" ? "active" : ""}
              type="button"
              onClick={() => setMode("split")}
            >
              Split
            </button>
            <button
              className={mode === "preview" ? "active" : ""}
              type="button"
              onClick={() => setMode("preview")}
            >
              Preview
            </button>
          </div>
          <div className="format-toolbar" aria-label="Markdown formatting">
            {tools.map(([label, prefix, suffix]) => (
              <button
                key={label}
                type="button"
                onClick={() => insert(prefix, suffix)}
                title={`Insert ${label.toLowerCase()}`}
              >
                {label}
              </button>
            ))}
          </div>
          <div className={`document-panes mode-${mode}`}>
            {mode !== "preview" && (
              <textarea
                ref={editorRef}
                className="markdown-editor"
                aria-label="Markdown body"
                value={fields.body}
                onChange={(event) => update("body", event.target.value)}
                placeholder={
                  fields.collection === "writing"
                    ? "Start the note here…"
                    : fields.collection === "links"
                      ? "Why is this worth returning to?"
                      : "Add context or a reflection…"
                }
                spellCheck="true"
              />
            )}
            {mode !== "write" && (
              <article className="live-preview" aria-label="Rendered Markdown preview">
                {deferredBody ? (
                  <ReactMarkdown remarkPlugins={[remarkGfm]}>{deferredBody}</ReactMarkdown>
                ) : (
                  <p className="preview-placeholder">The live preview will grow here.</p>
                )}
              </article>
            )}
          </div>
          <footer className="editor-footer">
            <span>{fields.body.trim() ? fields.body.trim().split(/\s+/).length : 0} words</span>
            <span>Markdown · Obsidian compatible</span>
            <kbd>⌘ S</kbd>
            <span>save</span>
          </footer>
        </section>
      </div>
    </div>
  )
}

function Field({
  label,
  field,
  issue,
  hint,
  children,
}: {
  label: string
  field: keyof EditorFields
  issue?: string
  hint?: string
  children: React.ReactNode
}) {
  return (
    <label className={`editor-field${issue ? " invalid" : ""}`}>
      <span>{label}</span>
      {children}
      {issue ? <small className="field-error">{issue}</small> : hint ? <small>{hint}</small> : null}
    </label>
  )
}
