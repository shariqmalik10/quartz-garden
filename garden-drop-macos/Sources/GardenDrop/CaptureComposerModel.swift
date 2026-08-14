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
        self.vaultConfiguration = vaultConfiguration
        self.writer = CaptureWriter(vaultRoot: vaultConfiguration.rootURL)
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

        let draft = CaptureDraft(
            id: CaptureID.make(),
            title: source.title,
            source: source,
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
}
