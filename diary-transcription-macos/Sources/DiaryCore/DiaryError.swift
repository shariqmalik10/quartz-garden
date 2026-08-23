import Foundation

public enum DiaryError: LocalizedError, Equatable {
    case vaultNotConfigured
    case invalidVault(URL)
    case emptyEntry
    case bookmarkMissing
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case fileCoordinationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .vaultNotConfigured:
            "Choose an Obsidian vault before saving an entry."
        case let .invalidVault(url):
            "The selected vault is not an existing directory: \(url.path)"
        case .emptyEntry:
            "Enter some text before saving."
        case .bookmarkMissing:
            "No saved vault bookmark was found."
        case .bookmarkCreationFailed:
            "macOS could not create a persistent vault bookmark."
        case .bookmarkResolutionFailed:
            "The saved vault bookmark could not be resolved. Choose the vault again."
        case let .fileCoordinationFailed(message):
            "The diary file could not be coordinated: \(message)"
        }
    }
}
