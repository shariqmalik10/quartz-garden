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
            case .error: "Error"
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

    var status: Status = .error("Choose an Obsidian vault to begin.")
    var testEntry = ""
    var vaultPath: String?
    var isSaving = false

    private let writer: DiaryWriter
    private let bookmarks: SecurityScopedBookmarkStore
    private var vaultAccess: VaultAccess?

    init(
        writer: DiaryWriter = DiaryWriter(),
        bookmarks: SecurityScopedBookmarkStore = SecurityScopedBookmarkStore()
    ) {
        self.writer = writer
        self.bookmarks = bookmarks
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
        panel.message = "Select the existing folder that contains your Obsidian vault."
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

    func saveTestEntry() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let fileURL = try await writer.append(testEntry)
            testEntry = ""
            status = .saved(fileURL.lastPathComponent)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func activate(_ access: VaultAccess) async throws {
        _ = try await writer.configureVault(access.url)
        vaultAccess = access
        vaultPath = access.url.path
        status = .ready("Diary folder is available.")
    }
}
