import Foundation

struct CaptureMarkdownRenderer: Sendable {
    func render(_ draft: CaptureDraft, attachmentRelativePath: String?) -> String {
        let sourceURL = draft.source.url?.absoluteString ?? ""
        let attachmentValue = attachmentRelativePath.map { "[[\($0)]]" }
        let thought = draft.thought.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceLine: String

        if let sourceURL = draft.source.url {
            sourceLine = "[Open original](<\(sourceURL.absoluteString)>)"
        } else {
            sourceLine = "Captured from the clipboard."
        }

        var lines = [
            "---",
            "id: \(yamlScalar(draft.id))",
            "kind: capture",
            "title: \(yamlScalar(draft.title))",
            "source: \(yamlScalar(sourceURL))",
            "source_type: \(draft.source.type.rawValue)",
            "captured_at: \(yamlScalar(iso8601(draft.capturedAt)))",
            "area: \(yamlScalar("[[\(draft.areaName)]]"))",
            "visibility: \(draft.visibility.rawValue)",
            "tags:",
            "  - capture",
            "metadata_status: \(draft.metadataStatus.rawValue)",
        ]

        if let attachmentValue {
            lines.append("attachments:")
            lines.append("  - \(yamlScalar(attachmentValue))")
        } else {
            lines.append("attachments: []")
        }

        lines.append(contentsOf: [
            "---",
            "",
            "## Thought",
            "",
            thought.isEmpty ? "_No thought added._" : thought,
            "",
            "## Source",
            "",
            sourceLine,
            "",
            "Area: [[\(draft.areaName)]]",
        ])

        if let capturedText = draft.source.capturedText,
           !capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(contentsOf: [
                "",
                "## Captured text",
                "",
                capturedText,
            ])
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Renders the append-only entry used when a user chooses an existing
    /// Markdown file (for example `Templates/Blog Link.md` or a personal
    /// reading list). The marker makes retries idempotent without requiring a
    /// second index file.
    func renderLinkEntry(
        _ draft: CaptureDraft,
        captureID: String,
        attachmentRelativePath: String?
    ) -> String {
        let thought = draft.thought.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [
            "<!-- garden-drop:\(captureID) -->",
            "### \(plainText(draft.title))",
            "",
            "- **Saved:** \(iso8601(draft.capturedAt))",
        ]

        if let sourceURL = draft.source.url {
            lines.append("- **Link:** [Open original](<\(sourceURL.absoluteString)>)")
        } else {
            lines.append("- **Link:** _No web link captured._")
        }

        if !thought.isEmpty {
            lines.append("- **Why:** \(thought.replacingOccurrences(of: "\n", with: " "))")
        }

        if let attachmentRelativePath {
            lines.append("- **Attachment:** [[\(attachmentRelativePath)]]")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func yamlScalar(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    private func plainText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
