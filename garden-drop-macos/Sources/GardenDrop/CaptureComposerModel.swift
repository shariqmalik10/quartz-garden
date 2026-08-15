import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CaptureComposerStatus: Sendable {
    case idle
    case saving
    case saved(CaptureResult)
    case failed(String)
}
@MainActor
final class CaptureComposerModel: ObservableObject {
    @Published var linkText: String
    @Published var draftInput = ""
    @Published var thought = ""
    @Published var selectedArea = AreaOption.defaults[0]
    @Published private(set) var droppedAttachment: CaptureAttachment? = nil
    @Published private(set) var status: CaptureComposerStatus = .idle

    let source: CaptureSource
    let vaultConfiguration: VaultConfiguration

    private let writer: CaptureWriter

    init(
        source: CaptureSource = .sample,
        vaultConfiguration: VaultConfiguration = .runtime
    ) {
        self.source = source
        self.linkText = source.url?.absoluteString ?? ""
        self.vaultConfiguration = vaultConfiguration
        self.writer = CaptureWriter(vaultRoot: vaultConfiguration.rootURL)
    }

    var activeSource: CaptureSource {
        guard let url = validatedLinkURL else {
            if let droppedAttachment {
                let type: CaptureSourceType = droppedAttachment.mimeType?.hasPrefix("image/") == true
                    ? .image
                    : .text
                return CaptureSource(
                    type: type,
                    title: droppedAttachment.fileName,
                    url: nil,
                    domain: nil,
                    excerpt: nil,
                    capturedText: nil,
                    attachment: droppedAttachment
                )
            }
            return source
        }

        let domain = url.host?.lowercased()
        return CaptureSource(
            type: .web,
            title: domain ?? "Web link",
            url: url,
            domain: domain,
            excerpt: nil,
            capturedText: nil,
            attachment: nil
        )
    }

    var hasValidLink: Bool {
        validatedLinkURL != nil
    }

    var hasCaptureContent: Bool {
        hasValidLink
            || !thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || droppedAttachment != nil
    }

    var hasPendingInput: Bool {
        !draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canPlant: Bool {
        hasCaptureContent || hasPendingInput
    }

    var linkValidationMessage: String? {
        if linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        if !hasValidLink {
            return "Use a valid http:// or https:// link."
        }
        return nil
    }

    var isSaving: Bool {
        if case .saving = status {
            return true
        }
        return false
    }

    var visibility: CaptureVisibility {
        selectedArea.visibility
    }

    var vaultLabel: String {
        if ProcessInfo.processInfo.environment["GARDEN_DROP_VAULT"] != nil {
            return "Configured vault"
        }
        return "Fixture vault · local only"
    }

    func save() {
        guard !isSaving else {
            return
        }

        guard hasCaptureContent else {
            status = .failed("Add a link, note, or file before planting it.")
            return
        }

        let captureSource = activeSource

        let draft = CaptureDraft(
            id: CaptureID.make(),
            title: title(for: captureSource),
            source: captureSource,
            thought: thought,
            areaName: selectedArea.name,
            visibility: selectedArea.visibility,
            capturedAt: Date(),
            metadataStatus: .complete
        )

        status = .saving

        Task { @MainActor in
            do {
                let result = try await writer.write(draft)
                status = .saved(result)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func commitDraftInput() {
        let trimmedInput = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return
        }

        if let url = normalizedHTTPURL(from: trimmedInput) {
            linkText = url.absoluteString
        } else {
            linkText = ""
            if thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                thought = trimmedInput
            } else {
                thought += "\n\n\(trimmedInput)"
            }
        }

        draftInput = ""
        status = .idle
    }

    func acceptDroppedText(_ text: String) {
        draftInput = text
        commitDraftInput()
    }

    func acceptDroppedFile(_ url: URL) {
        guard url.isFileURL,
              let data = try? Data(contentsOf: url) else {
            status = .failed("Garden Drop could not read that file.")
            return
        }

        let fileName = url.lastPathComponent.isEmpty ? "Dropped file" : url.lastPathComponent
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
        droppedAttachment = CaptureAttachment(
            fileName: fileName,
            data: data,
            mimeType: mimeType
        )
        linkText = ""
        draftInput = ""
        status = .idle
    }

    func clearCapture() {
        linkText = source.url?.absoluteString ?? ""
        draftInput = ""
        thought = ""
        droppedAttachment = nil
        status = .idle
    }

    private var validatedLinkURL: URL? {
        normalizedHTTPURL(from: linkText)
    }

    private func normalizedHTTPURL(from value: String) -> URL? {
        let trimmedLink = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else {
            return nil
        }

        let candidate = trimmedLink.contains("://")
            ? trimmedLink
            : "https://\(trimmedLink)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        return components.url
    }

    private func title(for captureSource: CaptureSource) -> String {
        if captureSource.url != nil || captureSource.attachment != nil {
            return captureSource.title
        }

        let firstLine = thought
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
            ?? ""
        let trimmedTitle = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled note" : String(trimmedTitle.prefix(72))
    }
}
