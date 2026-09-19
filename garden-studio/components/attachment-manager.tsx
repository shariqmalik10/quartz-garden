"use client"

import { useId, useState } from "react"

import { attachmentPathFromWikilink } from "@/lib/attachments"

type UploadResponse = {
  ok?: boolean
  message?: string
  path?: string
  wikilink?: string
  mime?: string
}

export function AttachmentManager({
  entryPath,
  attachments,
  mediaPolicy,
  demo,
  onAttach,
  onRemove,
}: {
  entryPath?: string
  attachments: string[]
  mediaPolicy: "reference" | "owned"
  demo: boolean
  onAttach: (wikilink: string, filePath: string, isImage: boolean) => void
  onRemove: (wikilink: string, filePath: string) => void
}) {
  const inputId = useId()
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState("")
  const [error, setError] = useState("")

  async function upload(file: File) {
    if (!entryPath) return
    setBusy(true)
    setError("")
    setNotice("Uploading to the private vault…")
    const form = new FormData()
    form.set("entryPath", entryPath)
    form.set("file", file)
    const response = await fetch("/api/attachments/upload", { method: "POST", body: form })
    const result = (await response.json()) as UploadResponse
    if (!response.ok || !result.wikilink || !result.path) {
      setError(result.message || "The attachment upload failed.")
      setNotice("")
      setBusy(false)
      return
    }
    onAttach(result.wikilink, result.path, Boolean(result.mime?.startsWith("image/")))
    setNotice(result.message || "Attachment added.")
    setBusy(false)
  }

  return (
    <section className="attachment-manager" aria-labelledby={`${inputId}-heading`}>
      <div className="attachment-heading">
        <div>
          <strong id={`${inputId}-heading`}>Private attachments</strong>
          <small>
            {mediaPolicy === "owned"
              ? "Owned media can cross into the reviewed public preview."
              : "This area uses reference media; uploads stay private and are omitted from export."}
          </small>
        </div>
        <span className={`media-policy policy-${mediaPolicy}`}>{mediaPolicy}</span>
      </div>

      {entryPath ? (
        <label className={`attachment-upload${busy ? " busy" : ""}`} htmlFor={inputId}>
          <input
            id={inputId}
            type="file"
            accept="image/jpeg,image/png,image/webp,image/gif,application/pdf"
            disabled={busy}
            onChange={(event) => {
              const file = event.target.files?.[0]
              if (file) void upload(file)
              event.currentTarget.value = ""
            }}
          />
          <span>{busy ? "Uploading…" : "Choose image or PDF"}</span>
          <small>JPEG, PNG, WebP, GIF, or PDF · 8 MB maximum</small>
        </label>
      ) : (
        <p className="attachment-first-save">
          Save this link once to create its Obsidian attachment folder.
        </p>
      )}

      {error && (
        <p className="attachment-notice error" role="alert">
          {error}
        </p>
      )}
      {notice && (
        <p className="attachment-notice" role="status">
          {notice}
        </p>
      )}

      {attachments.length > 0 && (
        <ul className="attachment-list">
          {attachments.map((wikilink) => {
            const filePath = attachmentPathFromWikilink(wikilink)
            if (!filePath) return null
            return (
              <li key={wikilink}>
                <span>
                  <strong>{filePath.split("/").at(-1)}</strong>
                  <small>{filePath}</small>
                </span>
                {!demo && (
                  <a
                    href={`/api/attachments/file?path=${encodeURIComponent(filePath)}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    View
                  </a>
                )}
                <button
                  type="button"
                  onClick={() => {
                    onRemove(wikilink, filePath)
                    setNotice("Reference removed; the private file was kept.")
                  }}
                >
                  Remove reference
                </button>
              </li>
            )
          })}
        </ul>
      )}
    </section>
  )
}
