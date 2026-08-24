import Foundation

enum ObsidianLinkError: LocalizedError, Equatable {
  case fileOutsideVault
  case invalidURL

  var errorDescription: String? {
    switch self {
    case .fileOutsideVault:
      "The saved entry is outside the connected Obsidian vault."
    case .invalidURL:
      "Yap could not build an Obsidian link for this entry."
    }
  }
}

enum ObsidianLink {
  static func openURL(vaultURL: URL, fileURL: URL) throws -> URL {
    let rootPath = vaultURL.resolvingSymlinksInPath().standardizedFileURL.path
    let filePath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
    guard filePath.hasPrefix(rootPath + "/") else {
      throw ObsidianLinkError.fileOutsideVault
    }
    var components = URLComponents()
    components.scheme = "obsidian"
    components.host = "open"
    components.queryItems = [URLQueryItem(name: "path", value: filePath)]
    guard let url = components.url else {
      throw ObsidianLinkError.invalidURL
    }
    return url
  }
}
