import Foundation

public enum DiaryError: LocalizedError, Equatable {
  case vaultNotConfigured
  case invalidVault(URL)
  case emptyEntry
  case bookmarkMissing
  case bookmarkCreationFailed
  case bookmarkResolutionFailed
  case fileCoordinationFailed(String)
  case invalidEntryFile(URL)
  case entryFileMissing(URL)
  case invalidWritingDestination(URL)
  case entryFileAlreadyExists(URL)

  public var errorDescription: String? {
    switch self {
    case .vaultNotConfigured:
      "Choose an Obsidian vault before saving an entry."
    case .invalidVault(let url):
      "The selected vault is not an existing directory: \(url.path)"
    case .emptyEntry:
      "Enter some text before saving."
    case .bookmarkMissing:
      "No saved vault bookmark was found."
    case .bookmarkCreationFailed:
      "macOS could not create a persistent vault bookmark."
    case .bookmarkResolutionFailed:
      "The saved vault bookmark could not be resolved. Choose the vault again."
    case .fileCoordinationFailed(let message):
      "The diary file could not be coordinated: \(message)"
    case .invalidEntryFile(let url):
      "Choose a Markdown file inside the connected Obsidian vault: \(url.path)"
    case .entryFileMissing(let url):
      "The selected Markdown file no longer exists: \(url.path)"
    case .invalidWritingDestination(let url):
      "New blog drafts must be saved inside the vault's Writing folder: \(url.path)"
    case .entryFileAlreadyExists(let url):
      "A file already exists at the chosen blog-draft location: \(url.path)"
    }
  }
}
