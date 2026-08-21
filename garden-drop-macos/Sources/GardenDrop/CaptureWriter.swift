import Foundation

enum CaptureWriteError: LocalizedError, Equatable {
    case invalidPathComponent(String)
    case vaultNotConfigured
    case vaultUnavailable(URL)
    case noteAlreadyExists(URL)
    case attachmentAlreadyExists(URL)

    var errorDescription: String? {
        switch self {
        case .invalidPathComponent:
            return "The area or attachment name contains characters that cannot be used safely."
        case .vaultNotConfigured:
            return "Choose an Obsidian vault in Settings before saving."
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
    private let isConfigured: Bool
    private let fileManager: FileManager
    private let renderer: CaptureMarkdownRenderer

    init(
        vaultRoot: URL,
        isConfigured: Bool = true,
        fileManager: FileManager = .default,
        renderer: CaptureMarkdownRenderer = CaptureMarkdownRenderer()
    ) {
        self.vaultRoot = vaultRoot
        self.isConfigured = isConfigured
        self.fileManager = fileManager
        self.renderer = renderer
    }

    func write(_ draft: CaptureDraft) throws -> CaptureResult {
        guard isConfigured else {
            throw CaptureWriteError.vaultNotConfigured
        }

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

        let resolvedVaultRoot = VaultPathContainment.resolved(vaultRoot)
        try ensureDirectory(resolvedVaultRoot)

        let effectiveDraft = CaptureDraft(
            id: draft.id,
            title: draft.title,
            source: draft.source,
            thought: draft.thought,
            destination: draft.destination.resolved(in: resolvedVaultRoot),
            capturedAt: draft.capturedAt,
            metadataStatus: draft.metadataStatus
        )

        let destinationPath = try VaultPathValidator.validate(effectiveDraft.destination.relativePath)
        let destinationURL = resolvedVaultRoot.appendingPathComponent(
            destinationPath,
            isDirectory: effectiveDraft.destination.isFolder
        )
        guard VaultPathContainment.contains(destinationURL, inside: resolvedVaultRoot) else {
            throw CaptureWriteError.invalidPathComponent(destinationPath)
        }

        if effectiveDraft.destination.kind == .markdownFile {
            return try writeToMarkdownFile(
                effectiveDraft,
                captureID: captureID,
                attachmentName: attachmentName,
                destinationURL: destinationURL,
                vaultRoot: resolvedVaultRoot
            )
        }

        let captureDirectory = destinationURL
        let noteURL = captureDirectory.appendingPathComponent("\(captureID).md")
        guard VaultPathContainment.contains(noteURL, inside: resolvedVaultRoot) else {
            throw CaptureWriteError.invalidPathComponent(noteURL.path)
        }

        guard !fileManager.fileExists(atPath: noteURL.path) else {
            throw CaptureWriteError.noteAlreadyExists(noteURL)
        }

        var attachmentURL: URL?
        var attachmentRelativePath: String?

        if let attachmentName, let attachment = draft.source.attachment {
            let attachmentDirectory = resolvedVaultRoot
                .appendingPathComponent("Attachments", isDirectory: true)
                .appendingPathComponent("Captures", isDirectory: true)
                .appendingPathComponent(captureID, isDirectory: true)
            let destination = attachmentDirectory.appendingPathComponent(attachmentName)

            guard VaultPathContainment.contains(destination, inside: resolvedVaultRoot) else {
                throw CaptureWriteError.invalidPathComponent(attachmentName)
            }

            guard !fileManager.fileExists(atPath: destination.path) else {
                throw CaptureWriteError.attachmentAlreadyExists(destination)
            }

            try ensureDirectory(attachmentDirectory)
            try writeAtomically(attachment.data, to: destination)
            attachmentURL = destination
            attachmentRelativePath = "Attachments/Captures/\(captureID)/\(attachmentName)"
        }

        try ensureDirectory(captureDirectory)
        let markdown = renderer.render(effectiveDraft, attachmentRelativePath: attachmentRelativePath)
        try writeAtomically(Data(markdown.utf8), to: noteURL)

        return CaptureResult(noteURL: noteURL, attachmentURL: attachmentURL)
    }

    private func writeToMarkdownFile(
        _ draft: CaptureDraft,
        captureID: String,
        attachmentName: String?,
        destinationURL: URL,
        vaultRoot: URL
    ) throws -> CaptureResult {
        guard destinationURL.pathExtension.lowercased() == "md",
              fileManager.fileExists(atPath: destinationURL.path) else {
            throw CaptureWriteError.vaultUnavailable(destinationURL)
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

        var attachmentURL: URL?
        var attachmentRelativePath: String?

        if let attachmentName, let attachment = draft.source.attachment {
            let attachmentDirectory = vaultRoot
                .appendingPathComponent("Attachments", isDirectory: true)
                .appendingPathComponent("Captures", isDirectory: true)
                .appendingPathComponent(captureID, isDirectory: true)
            let destination = attachmentDirectory.appendingPathComponent(attachmentName)

            guard VaultPathContainment.contains(destination, inside: vaultRoot) else {
                throw CaptureWriteError.invalidPathComponent(attachmentName)
            }
            guard !fileManager.fileExists(atPath: destination.path) else {
                throw CaptureWriteError.attachmentAlreadyExists(destination)
            }

            try ensureDirectory(attachmentDirectory)
            try writeAtomically(attachment.data, to: destination)
            attachmentURL = destination
            attachmentRelativePath = "Attachments/Captures/\(captureID)/\(attachmentName)"
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
