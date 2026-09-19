import type { EditorFields } from "./content"

export type MarkdownCommand = {
  id: string
  label: string
  group: "Style" | "Structure" | "Obsidian"
  prefix: string
  suffix: string
  placeholder?: string
}

export const MARKDOWN_COMMANDS: MarkdownCommand[] = [
  {
    id: "heading",
    label: "Heading",
    group: "Structure",
    prefix: "## ",
    suffix: "",
    placeholder: "Heading",
  },
  {
    id: "bold",
    label: "Bold",
    group: "Style",
    prefix: "**",
    suffix: "**",
    placeholder: "strong text",
  },
  {
    id: "italic",
    label: "Italic",
    group: "Style",
    prefix: "_",
    suffix: "_",
    placeholder: "emphasis",
  },
  {
    id: "strike",
    label: "Strikethrough",
    group: "Style",
    prefix: "~~",
    suffix: "~~",
    placeholder: "revised thought",
  },
  {
    id: "link",
    label: "Web link",
    group: "Structure",
    prefix: "[",
    suffix: "](https://)",
    placeholder: "link text",
  },
  {
    id: "image",
    label: "Remote image",
    group: "Structure",
    prefix: "![",
    suffix: "](https://)",
    placeholder: "image description",
  },
  {
    id: "quote",
    label: "Blockquote",
    group: "Structure",
    prefix: "> ",
    suffix: "",
    placeholder: "Quoted thought",
  },
  {
    id: "bullets",
    label: "Bullet list",
    group: "Structure",
    prefix: "- ",
    suffix: "",
    placeholder: "List item",
  },
  {
    id: "numbered",
    label: "Numbered list",
    group: "Structure",
    prefix: "1. ",
    suffix: "",
    placeholder: "List item",
  },
  {
    id: "task",
    label: "Task",
    group: "Obsidian",
    prefix: "- [ ] ",
    suffix: "",
    placeholder: "Next action",
  },
  {
    id: "code",
    label: "Inline code",
    group: "Style",
    prefix: "`",
    suffix: "`",
    placeholder: "code",
  },
  {
    id: "codeblock",
    label: "Code block",
    group: "Structure",
    prefix: "```text\n",
    suffix: "\n```",
    placeholder: "code",
  },
  { id: "divider", label: "Divider", group: "Structure", prefix: "\n---\n", suffix: "" },
  {
    id: "callout",
    label: "Callout",
    group: "Obsidian",
    prefix: "> [!NOTE]\n> ",
    suffix: "",
    placeholder: "A useful aside",
  },
  {
    id: "table",
    label: "Table",
    group: "Structure",
    prefix: "| Column | Column |\n| --- | --- |\n| Value | Value |",
    suffix: "",
  },
  {
    id: "wikilink",
    label: "Wikilink",
    group: "Obsidian",
    prefix: "[[",
    suffix: "]]",
    placeholder: "Note title",
  },
  {
    id: "embed",
    label: "Obsidian embed",
    group: "Obsidian",
    prefix: "![[",
    suffix: "]]",
    placeholder: "Note or attachment",
  },
]

export type WritingTemplate = {
  id: string
  label: string
  description: string
  body: string
  tags: string[]
}

export const WRITING_TEMPLATES: WritingTemplate[] = [
  {
    id: "garden-note",
    label: "Garden note",
    description: "A small idea that can grow through links.",
    tags: ["note"],
    body: "## The thought\n\n\n\n## What it connects to\n\n- [[Related note]]\n\n## What changed my mind\n\n",
  },
  {
    id: "essay",
    label: "Essay",
    description: "A considered argument with room for evidence.",
    tags: ["essay"],
    body: "## Premise\n\n\n\n## What I observed\n\n\n\n## The argument\n\n\n\n## What remains uncertain\n\n",
  },
  {
    id: "build-log",
    label: "Build log",
    description: "Decisions, experiments, and lessons from making something.",
    tags: ["building", "project-log"],
    body: "## What I am building\n\n\n\n## Decisions\n\n- \n\n## What did not work\n\n\n\n## Next\n\n- [ ] \n",
  },
  {
    id: "reading-note",
    label: "Reading note",
    description: "A source, its central claim, and your response.",
    tags: ["reading"],
    body: "## Source\n\n\n\n## The central idea\n\n\n\n## Lines worth keeping\n\n> \n\n## My response\n\n\n\n## Related\n\n- [[Related note]]\n",
  },
]

export function applyMarkdownCommand(
  body: string,
  start: number,
  end: number,
  command: MarkdownCommand,
) {
  const selected = body.slice(start, end)
  const content = selected || command.placeholder || ""
  const inserted = `${command.prefix}${content}${command.suffix}`
  const next = `${body.slice(0, start)}${inserted}${body.slice(end)}`
  const selectionStart = start + command.prefix.length
  return {
    body: next,
    selectionStart,
    selectionEnd: selectionStart + content.length,
  }
}

export function fieldsWithTemplate(fields: EditorFields, templateId: string) {
  const template = WRITING_TEMPLATES.find((item) => item.id === templateId)
  if (!template || fields.collection !== "writing") return fields
  return {
    ...fields,
    body: template.body,
    tags: [...new Set([...fields.tags, ...template.tags])],
  }
}

export function documentStats(body: string) {
  const trimmed = body.trim()
  const words = trimmed ? trimmed.split(/\s+/).length : 0
  return {
    words,
    characters: body.length,
    readingMinutes: words === 0 ? 0 : Math.max(1, Math.ceil(words / 220)),
  }
}
