import Foundation

enum CaptureWriteError: LocalizedError, Equatable {
    case invalidPathComponent(String)
    case vaultUnavailable(URL)
    case noteAlreadyExists(URL)
    case attachmentAlreadyExists(URL)

    var errorDescription: String? {
        switch self {
        case .invalidPathComponent:
            return "The area or attachment name contains characters that cannot be used safely."
        case .vaultUnavailable:
            return "The vault folder is unavailable. Choose it again in Settings."
        case .noteAlreadyExists:
            return "A capture with this id already exists."
        case .attachmentAlreadyExists:
            return "The capture attachment already exists."
        }
    }
}
actor CaptureWriter {
    private let vaultRoot: URL
    private let fileManager: FileManager
    private let renderer: CaptureMarkdownRenderer

    init(
        vaultRoot: URL,
        fileManager: FileManager = .default,
        renderer: CaptureMarkdownRenderer = CaptureMarkdownRenderer()
    ) {
        self.vaultRoot = vaultRoot
        self.fileManager = fileManager
        self.renderer = renderer
    }

    func write(_ draft: CaptureDraft) throws -> CaptureResult {
        let captureID = try VaultNameValidator.validate(draft.id)
        let attachmentName = try draft.source.attachment.map {
            try VaultNameValidator.validate($0.fileName)
        }

        let accessStarted = vaultRoot.startAccessingSecurityScopedResource()
        defer {
            if accessStarted {
                vaultRoot.stopAccessingSecurityScopedResource()
            }
        }

        try ensureDirectory(vaultRoot)

        let destinationPath = try VaultPathValidator.validate(draft.destination.relativePath)
        let destinationURL = vaultRoot.appendingPathComponent(destinationPath, isDirectory: draft.destination.isFolder)

        if draft.destination.kind == .markdownFile {
            return try writeToMarkdownFile(
                draft,
                captureID: captureID,
                attachmentName: attachmentName,
                destinationURL: destinationURL
            )
        }

        let captureDirectory = destinationURL
        let noteURL = captureDirectory.appendingPathComponent("\(captureID).md")

        guard !fileManager.fileExists(atPath: noteURL.path) else {
            throw CaptureWriteError.noteAlreadyExists(noteURL)
        }

        var attachmentURL: URL?
        var attachmentRelativePath: String?

        if let attachmentName, let attachment = draft.source.attachment {
            let attachmentDirectory = vaultRoot
                .appendingPathComponent("Attachments", isDirectory: true)
                .appendingPathComponent("Captures", isDirectory: true)
                .appendingPathComponent(captureID, isDirectory: true)
            let destination = attachmentDirectory.appendingPathComponent(attachmentName)

            guard !fileManager.fileExists(atPath: destination.path) else {
                throw CaptureWriteError.attachmentAlreadyExists(destination)
            }

            try ensureDirectory(attachmentDirectory)
            try writeAtomically(attachment.data, to: destination)
            attachmentURL = destination
            attachmentRelativePath = "Attachments/Captures/\(captureID)/\(attachmentName)"
        }

        try ensureDirectory(captureDirectory)
        let markdown = renderer.render(draft, attachmentRelativePath: attachmentRelativePath)
        try writeAtomically(Data(markdown.utf8), to: noteURL)

        return CaptureResult(noteURL: noteURL, attachmentURL: attachmentURL)
    }

    private func writeToMarkdownFile(
        _ draft: CaptureDraft,
        captureID: String,
        attachmentName: String?,
        destinationURL: URL
    ) throws -> CaptureResult {
        guard destinationURL.pathExtension.lowercased() == "md",
              fileManager.fileExists(atPath: destinationURL.path) else {
            throw CaptureWriteError.vaultUnavailable(destinationURL)
        }

        var attachmentURL: URL?
        var attachmentRelativePath: String?

        if let attachmentName, let attachment = draft.source.attachment {
            let attachmentDirectory = vaultRoot
                .appendingPathComponent("Attachments", isDirectory: true)
                .appendingPathComponent("Captures", isDirectory: true)
                .appendingPathComponent(captureID, isDirectory: true)
            let destination = attachmentDirectory.appendingPathComponent(attachmentName)

            guard !fileManager.fileExists(atPath: destination.path) else {
                throw CaptureWriteError.attachmentAlreadyExists(destination)
            }

            try ensureDirectory(attachmentDirectory)
            try writeAtomically(attachment.data, to: destination)
            attachmentURL = destination
            attachmentRelativePath = "Attachments/Captures/\(captureID)/\(attachmentName)"
        }

        let existingData: Data
        do {
            existingData = try Data(contentsOf: destinationURL)
        } catch {
            throw CaptureWriteError.vaultUnavailable(destinationURL)
        }

        let existingText = String(decoding: existingData, as: UTF8.self)
        guard !existingText.contains("<!-- garden-drop:\(captureID) -->") else {
            throw CaptureWriteError.noteAlreadyExists(destinationURL)
        }

        let entry = renderer.renderLinkEntry(
            draft,
            captureID: captureID,
            attachmentRelativePath: attachmentRelativePath
        )
        let separator = existingText.hasSuffix("\n") ? "\n" : "\n\n"
        let updated = existingText + separator + entry
        try writeAtomically(Data(updated.utf8), to: destinationURL)

        return CaptureResult(noteURL: destinationURL, attachmentURL: attachmentURL)
    }

    private func ensureDirectory(_ directory: URL) throws {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw CaptureWriteError.vaultUnavailable(vaultRoot)
        }
    }

    private func writeAtomically(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw CaptureWriteError.vaultUnavailable(vaultRoot)
        }
    }
}
