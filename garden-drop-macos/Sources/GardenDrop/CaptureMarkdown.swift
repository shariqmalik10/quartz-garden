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
}
