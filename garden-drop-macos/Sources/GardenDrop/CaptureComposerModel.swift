import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CaptureComposerFocusTarget: Equatable, Sendable {
    case source
    case thought
}

enum CaptureComposerState: Equatable, Sendable {
    case empty
    case prepared
    case saving
    case done(CaptureResult)
    case error(String)

    var isSaving: Bool {
        if case .saving = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        guard case .error(let message) = self else {
            return nil
        }
        return message
    }
}

// Kept as a compatibility surface for the current notch view while the
// composer moves to CaptureComposerState. The model's state is the source of
// truth; this type is only the older callback/view representation.
enum CaptureComposerStatus: Equatable, Sendable {
    case idle
    case saving
    case saved(CaptureResult)
    case failed(String)

    var composerState: CaptureComposerState {
        switch self {
        case .idle:
            return .prepared
        case .saving:
            return .saving
        case .saved(let result):
            return .done(result)
        case .failed(let message):
            return .error(message)
        }
    }
}

extension CaptureComposerState {
    var compatibilityStatus: CaptureComposerStatus {
        switch self {
        case .empty, .prepared:
            return .idle
        case .saving:
            return .saving
        case .done(let result):
            return .saved(result)
        case .error(let message):
            return .failed(message)
        }
    }
}

@MainActor
final class CaptureComposerModel: ObservableObject {
    @Published var linkText: String {
        didSet { draftDidChange() }
    }
    @Published var draftInput = "" {
        didSet { draftDidChange() }
    }
    @Published var thought = "" {
        didSet { draftDidChange() }
    }
    @Published var selectedDestination: CaptureDestination {
        didSet { draftDidChange() }
    }
    @Published private(set) var droppedAttachment: CaptureAttachment? = nil {
        didSet { draftDidChange() }
    }
    @Published private(set) var state: CaptureComposerState = .empty
    @Published private(set) var isDirty = false
    @Published private(set) var status: CaptureComposerStatus = .idle

    let source: CaptureSource
    @Published private(set) var vaultConfiguration: VaultConfiguration
    let destinationStore: DestinationStore

    private var writer: CaptureWriter
    private var savedSnapshot: DraftSnapshot
    private var isApplyingDraftChanges = false

    init(
        source: CaptureSource = .sample,
        vaultConfiguration: VaultConfiguration = .runtime,
        destinationStore: DestinationStore = DestinationStore()
    ) {
        let initialLinkText = source.url?.absoluteString ?? ""
        let initialDraftInput = ""
        let initialThought = ""
        let initialDestination = destinationStore.defaultDestination(in: vaultConfiguration.rootURL)
        let initialAttachment: CaptureAttachment? = nil

        self.source = source
        self.linkText = initialLinkText
        self.draftInput = initialDraftInput
        self.thought = initialThought
        self.selectedDestination = initialDestination
        self.droppedAttachment = initialAttachment
        self.vaultConfiguration = vaultConfiguration
        self.destinationStore = destinationStore
        self.writer = CaptureWriter(
            vaultRoot: vaultConfiguration.rootURL,
            isConfigured: vaultConfiguration.isConfigured
        )
        self.savedSnapshot = DraftSnapshot(
            linkText: initialLinkText,
            draftInput: initialDraftInput,
            thought: initialThought,
            selectedDestination: initialDestination,
            droppedAttachment: initialAttachment
        )

        let initialState: CaptureComposerState = Self.sourceHasContent(source)
            ? .prepared
            : .empty
        self.state = initialState
        self.status = initialState.compatibilityStatus
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
            return retainsInitialSource ? source : .blank
        }

        if source.url == url, droppedAttachment == nil {
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
        hasSource
            || !thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        state.isSaving
    }

    var hasUnsavedChanges: Bool {
        isDirty
    }

    var hasSource: Bool {
        hasValidLink || droppedAttachment != nil || retainsInitialSource
    }

    var hasInitialSource: Bool {
        Self.sourceHasContent(source)
    }

    var initialFocusTarget: CaptureComposerFocusTarget {
        hasInitialSource ? .thought : .source
    }

    var visibility: CaptureVisibility {
        selectedDestination.visibility
    }

    var selectedArea: AreaOption {
        get {
            AreaOption(
                name: selectedDestination.areaName,
                visibility: selectedDestination.visibility
            )
        }
        set {
            selectedDestination = newValue.destination
        }
    }

    var vaultLabel: String {
        vaultConfiguration.isConfigured
            ? "Vault · \(vaultConfiguration.displayName)"
            : "Vault not configured"
    }

    func chooseDestination(_ destination: CaptureDestination) {
        destinationStore.remember(destination)
        selectedDestination = destination.resolved(in: vaultConfiguration.rootURL)
    }

    func updateVaultConfiguration(_ configuration: VaultConfiguration) {
        guard configuration != vaultConfiguration else {
            return
        }

        let wasConfigured = vaultConfiguration.isConfigured
        vaultConfiguration = configuration
        writer = CaptureWriter(
            vaultRoot: configuration.rootURL,
            isConfigured: configuration.isConfigured
        )
        // A long-lived composer can be created before a persisted bookmark is
        // resolved or while no vault is configured. Re-select from the store
        // when the vault changes so it receives the last successful, valid
        // destination for that vault instead of retaining the placeholder's
        // first quick destination.
        selectedDestination = !wasConfigured && configuration.isConfigured
            ? destinationStore.defaultDestination(in: configuration.rootURL)
            : selectedDestination.resolved(in: configuration.rootURL)
    }

    func isSelectedDestination(_ destination: CaptureDestination) -> Bool {
        selectedDestination.id == destination.id
    }

    func save() {
        guard !isSaving else {
            return
        }

        if hasPendingInput {
            commitDraftInput()
        }

        guard vaultConfiguration.isConfigured else {
            setState(.error("Choose an Obsidian vault in Settings before saving."))
            return
        }

        guard hasCaptureContent else {
            setState(.error("Add a link, note, or file before planting it."))
            return
        }

        let captureSource = activeSource
        let draftSnapshot = currentSnapshot

        let draft = CaptureDraft(
            id: CaptureID.make(),
            title: title(for: captureSource),
            source: captureSource,
            thought: thought,
            destination: selectedDestination,
            capturedAt: Date(),
            metadataStatus: .complete
        )

        setState(.saving)

        Task { @MainActor in
            do {
                let result = try await writer.write(draft)
                destinationStore.markLastUsed(draft.destination)
                if currentSnapshot == draftSnapshot {
                    savedSnapshot = draftSnapshot
                    isDirty = false
                    setState(.done(result))
                } else {
                    setState(.prepared)
                }
            } catch {
                setState(.error(error.localizedDescription))
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
    }

    func acceptDroppedText(_ text: String) {
        draftInput = text
        commitDraftInput()
    }

    func acceptDroppedFile(_ url: URL) {
        guard url.isFileURL,
              let data = try? Data(contentsOf: url) else {
            setState(.error("Garden Drop could not read that file."))
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
    }

    func clearCapture() {
        guard !isSaving else {
            return
        }

        isApplyingDraftChanges = true
        linkText = source.url?.absoluteString ?? ""
        draftInput = ""
        thought = ""
        droppedAttachment = nil
        isApplyingDraftChanges = false
        refreshDraftState()
    }

    private var validatedLinkURL: URL? {
        normalizedHTTPURL(from: linkText)
    }

    private var retainsInitialSource: Bool {
        guard Self.sourceHasContent(source) else {
            return false
        }

        if let sourceURL = source.url {
            return validatedLinkURL == sourceURL
        }

        return source.attachment != nil || source.capturedText != nil
    }

    private var currentSnapshot: DraftSnapshot {
        DraftSnapshot(
            linkText: linkText,
            draftInput: draftInput,
            thought: thought,
            selectedDestination: selectedDestination,
            droppedAttachment: droppedAttachment
        )
    }

    private func draftDidChange() {
        guard !isApplyingDraftChanges else {
            return
        }
        refreshDraftState()
    }

    private func refreshDraftState() {
        isDirty = currentSnapshot != savedSnapshot

        guard !isSaving else {
            return
        }

        let nextState: CaptureComposerState = canPlant ? .prepared : .empty
        if state != nextState {
            setState(nextState)
        }
    }

    private func setState(_ newState: CaptureComposerState) {
        state = newState
        status = newState.compatibilityStatus
    }

    private static func sourceHasContent(_ source: CaptureSource) -> Bool {
        source.url != nil
            || source.attachment != nil
            || !(source.capturedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
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

    private struct DraftSnapshot: Equatable {
        let linkText: String
        let draftInput: String
        let thought: String
        let selectedDestination: CaptureDestination
        let droppedAttachment: CaptureAttachment?
    }
}
