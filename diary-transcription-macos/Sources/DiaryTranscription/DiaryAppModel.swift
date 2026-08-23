import AppKit
import DiaryCore
import Foundation
import Observation

@MainActor
@Observable
final class DiaryAppModel {
    enum Status: Equatable {
        case ready(String)
        case saved(String)
        case error(String)

        var title: String {
            switch self {
            case .ready: "Ready"
            case .saved: "Saved"
            case .error: "Needs attention"
            }
        }

        var detail: String {
            switch self {
            case let .ready(detail), let .saved(detail), let .error(detail): detail
            }
        }

        var symbolName: String {
            switch self {
            case .ready: "checkmark.circle"
            case .saved: "checkmark.circle.fill"
            case .error: "exclamationmark.triangle.fill"
            }
        }
    }

    enum ModelState: Equatable {
        case notInstalled
        case downloading(Double)
        case installed
        case loading
        case ready
        case failed(String)

        var isUsable: Bool {
            switch self {
            case .installed, .ready: true
            default: false
            }
        }
    }

    enum WorkflowState: Equatable {
        case idle
        case transcribing
        case saving
        case saved(fileName: String, preview: String)
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .transcribing, .saving: true
            default: false
            }
        }
    }

    struct Language: Identifiable, Hashable {
        let id: String
        let name: String
    }

    static let languages: [Language] = [
        .init(id: "en", name: "English"),
        .init(id: "ar", name: "Arabic"),
        .init(id: "de", name: "German"),
        .init(id: "el", name: "Greek"),
        .init(id: "es", name: "Spanish"),
        .init(id: "fr", name: "French"),
        .init(id: "it", name: "Italian"),
        .init(id: "ja", name: "Japanese"),
        .init(id: "ko", name: "Korean"),
        .init(id: "nl", name: "Dutch"),
        .init(id: "pl", name: "Polish"),
        .init(id: "pt", name: "Portuguese"),
        .init(id: "vi", name: "Vietnamese"),
        .init(id: "zh", name: "Chinese")
    ]

    let capture: AudioCaptureModel
    var status: Status = .error("Choose an Obsidian vault to begin.")
    var workflowState: WorkflowState = .idle
    var modelState: ModelState
    var testEntry = ""
    var vaultPath: String?
    var isSaving = false
    var shortcut: GlobalKeyBinding?
    var shortcutError: String?
    var languageCode: String {
        didSet { defaults.set(languageCode, forKey: Keys.language) }
    }

    private let writer: DiaryWriter
    private let bookmarks: SecurityScopedBookmarkStore
    private let transcriber: any LocalTranscriptionEngine
    private let pendingStore: PendingTranscriptionStore
    private let defaults: UserDefaults
    private let shortcutController: GlobalShortcutController
    private var vaultAccess: VaultAccess?
    private var modelWarmup: Task<Void, Error>?

    init(
        writer: DiaryWriter = DiaryWriter(),
        bookmarks: SecurityScopedBookmarkStore = SecurityScopedBookmarkStore(),
        capture: AudioCaptureModel = AudioCaptureModel(),
        transcriber: any LocalTranscriptionEngine = CohereTranscriptionEngine(),
        pendingStore: PendingTranscriptionStore = PendingTranscriptionStore(),
        defaults: UserDefaults = .standard,
        shortcutController: GlobalShortcutController = GlobalShortcutController()
    ) {
        self.writer = writer
        self.bookmarks = bookmarks
        self.capture = capture
        self.transcriber = transcriber
        self.pendingStore = pendingStore
        self.defaults = defaults
        self.shortcutController = shortcutController
        modelState = transcriber.isInstalled ? .installed : .notInstalled
        let storedLanguage = defaults.string(forKey: Keys.language) ?? "en"
        languageCode = Self.languages.contains(where: { $0.id == storedLanguage })
            ? storedLanguage
            : "en"
        defaults.set(languageCode, forKey: Keys.language)
        if let data = defaults.data(forKey: Keys.shortcut) {
            shortcut = try? JSONDecoder().decode(GlobalKeyBinding.self, from: data)
        }
        if capture.capturedURL != nil {
            workflowState = .failed("A recording from an earlier session is safe on this Mac. Retry it or discard it.")
        }
        DiaryAppDelegate.appModel = self
        Task { @MainActor [weak self] in
            await self?.restoreVault()
            self?.applyShortcutRegistration()
        }
    }

    var hasPendingRecording: Bool { capture.capturedURL != nil }
    var canRecord: Bool {
        vaultPath != nil
            && modelState.isUsable
            && !workflowState.isBusy
            && !isSaving
            && !hasPendingRecording
    }

    func restoreVault() async {
        guard vaultPath == nil else { return }
        guard bookmarks.hasBookmark else { return }
        do {
            let access = try bookmarks.restoreAccess()
            try await activate(access)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func chooseVault() async {
        let panel = NSOpenPanel()
        panel.title = "Choose Obsidian Vault"
        panel.message = "Select the existing folder that contains your Obsidian vault. Diary entries will be appended under Diary/."
        panel.prompt = "Choose Vault"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let access = try bookmarks.saveAndAccess(url)
            try await activate(access)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func installModel() async {
        guard !workflowState.isBusy else { return }
        if case .downloading = modelState { return }
        modelState = .downloading(0)
        do {
            try await transcriber.install { [weak self] fraction in
                self?.modelState = .downloading(min(1, max(0, fraction)))
            }
            modelState = .ready
            status = vaultPath == nil
                ? .error("The model is ready. Choose an Obsidian vault to finish setup.")
                : .ready("Local INT8 transcription is installed and ready offline.")
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    func removeModel() async {
        guard !capture.isRecording, !workflowState.isBusy else { return }
        do {
            try await transcriber.removeInstalledModel()
            modelState = .notInstalled
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    func handlePrimaryAction() async {
        if capture.isRecording {
            capture.stopRecording()
            await processPendingRecording()
            return
        }
        guard canRecord else {
            if vaultPath == nil {
                status = .error("Choose an Obsidian vault before recording.")
            } else if !modelState.isUsable {
                workflowState = .failed("Install the local transcription model in Settings before recording.")
            }
            return
        }
        workflowState = .idle
        await capture.startRecording()
        guard capture.isRecording else { return }
        modelState = .loading
        modelWarmup = Task { @MainActor [weak self, transcriber] in
            do {
                try await transcriber.prepareOffline()
                self?.modelState = .ready
            } catch {
                self?.modelState = .failed(error.localizedDescription)
                self?.modelWarmup = nil
                throw error
            }
        }
    }

    func retryPendingRecording() async {
        await processPendingRecording()
    }

    func discardPendingRecording() {
        guard let audioURL = capture.capturedURL else { return }
        capture.discardRecording()
        try? pendingStore.remove(for: audioURL)
        workflowState = capture.capturedURL == nil
            ? .idle
            : .failed("Another recovered recording is waiting. Retry it or discard it.")
    }

    func saveTestEntry() async {
        guard !isSaving, !workflowState.isBusy, !capture.isRecording else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let text = testEntry
            let fileURL = try await writer.append(text)
            testEntry = ""
            let preview = Self.preview(text)
            workflowState = .saved(fileName: fileURL.lastPathComponent, preview: preview)
            status = .saved(fileURL.lastPathComponent)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func openTodayDiary() async {
        do {
            let url = try await writer.diaryFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                status = .error("Today’s diary file does not exist yet.")
                return
            }
            NSWorkspace.shared.open(url)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func setShortcut(_ value: GlobalKeyBinding?) {
        do {
            try shortcutController.register(value) { [weak self] in
                Task { @MainActor in await self?.handlePrimaryAction() }
            }
            shortcut = value
            if let value, let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: Keys.shortcut)
            } else {
                defaults.removeObject(forKey: Keys.shortcut)
            }
            shortcutError = nil
        } catch {
            shortcutError = error.localizedDescription
        }
    }

    private func processPendingRecording() async {
        guard let audioURL = capture.capturedURL else { return }
        guard capture.elapsedTime >= 0.5 || capture.phase != .captured else {
            workflowState = .failed("That recording was too short to transcribe. It is still saved locally.")
            return
        }

        var pending: PendingTranscription
        do {
            if let saved = try pendingStore.load(for: audioURL) {
                pending = saved
            } else {
                let date = (try? audioURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                pending = PendingTranscription(audioPath: audioURL.path, capturedAt: date, transcript: nil)
                try pendingStore.save(pending, for: audioURL)
            }

            if let savedFilePath = pending.savedFilePath {
                try capture.completeRecording()
                try pendingStore.remove(for: audioURL)
                let fileName = URL(fileURLWithPath: savedFilePath).lastPathComponent
                if capture.capturedURL != nil {
                    workflowState = .failed("The diary entry was already saved. Another recovered recording is waiting for you.")
                    status = .saved(fileName)
                    return
                }
                workflowState = .saved(fileName: fileName, preview: Self.preview(pending.transcript ?? ""))
                status = .saved(fileName)
                return
            }

            if pending.transcript == nil {
                workflowState = .transcribing
                try await prepareModelForTranscription()
                let transcript = try await transcriber.transcribe(
                    audioURL: audioURL,
                    language: languageCode
                )
                pending.transcript = transcript
                try pendingStore.save(pending, for: audioURL)
            }

            guard let transcript = pending.transcript else {
                throw CohereEngineError.emptyTranscript
            }
            workflowState = .saving
            let fileURL = try await writer.append(
                transcript,
                at: pending.capturedAt,
                idempotencyKey: pending.entryID
            )
            pending.savedFilePath = fileURL.path
            try pendingStore.save(pending, for: audioURL)

            do {
                try capture.completeRecording()
                try pendingStore.remove(for: audioURL)
            } catch {
                workflowState = .failed("The diary entry was saved, but its retained audio could not be cleaned up: \(error.localizedDescription)")
                status = .saved(fileURL.lastPathComponent)
                return
            }
            if capture.capturedURL != nil {
                workflowState = .failed("The diary entry was saved. Another recovered recording is waiting for you.")
                status = .saved(fileURL.lastPathComponent)
                return
            }
            let preview = Self.preview(transcript)
            workflowState = .saved(fileName: fileURL.lastPathComponent, preview: preview)
            status = .saved(fileURL.lastPathComponent)
        } catch {
            modelWarmup = nil
            workflowState = .failed(error.localizedDescription)
        }
    }

    private func prepareModelForTranscription() async throws {
        do {
            if let modelWarmup {
                try await modelWarmup.value
            } else {
                modelState = .loading
                try await transcriber.prepareOffline()
            }
            modelWarmup = nil
            modelState = .ready
        } catch {
            modelWarmup = nil
            modelState = .failed(error.localizedDescription)
            throw error
        }
    }

    private func activate(_ access: VaultAccess) async throws {
        _ = try await writer.configureVault(access.url)
        vaultAccess = access
        vaultPath = access.url.path
        status = modelState.isUsable
            ? .ready("Diary folder and local transcription are ready.")
            : .ready("Diary folder is ready. Install the transcription model next.")
    }

    private func applyShortcutRegistration() {
        do {
            try shortcutController.register(shortcut) { [weak self] in
                Task { @MainActor in await self?.handlePrimaryAction() }
            }
            shortcutError = nil
        } catch {
            shortcut = nil
            defaults.removeObject(forKey: Keys.shortcut)
            shortcutError = error.localizedDescription
        }
    }

    private static func preview(_ text: String) -> String {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed.count > 120 ? "\(collapsed.prefix(117))…" : collapsed
    }

    private enum Keys {
        static let shortcut = "DiaryTranscription.globalShortcut"
        static let language = "DiaryTranscription.language"
    }
}
