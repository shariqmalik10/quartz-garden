import Foundation
import SwiftUI

enum CaptureComposerStatus: Sendable {
    case idle
    case saving
    case saved(CaptureResult)
    case failed(String)
}
@MainActor
final class CaptureComposerModel: ObservableObject {
    @Published var linkText: String
    @Published var thought = ""
    @Published var selectedArea = AreaOption.defaults[0]
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

    var linkValidationMessage: String? {
        if linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a link to capture it."
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

        guard hasValidLink else {
            status = .failed(linkValidationMessage ?? "Add a valid link to capture it.")
            return
        }

        let captureSource = activeSource

        let draft = CaptureDraft(
            id: CaptureID.make(),
            title: captureSource.title,
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

    private var validatedLinkURL: URL? {
        let trimmedLink = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
