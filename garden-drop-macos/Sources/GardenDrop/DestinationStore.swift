import AppKit
import Foundation

/// A place inside the vault where a capture can be planted.
///
/// Folder destinations create a new capture note in that folder. Markdown-file
/// destinations append a compact link entry to the existing note. Paths are
/// always relative to the selected vault root; absolute paths are never stored
/// in preferences.
enum CaptureDestinationKind: String, Codable, CaseIterable, Sendable {
    case folder
    case markdownFile

    var displayName: String {
        switch self {
        case .folder:
            return "Folder"
        case .markdownFile:
            return "Markdown file"
        }
    }

    var symbolName: String {
        switch self {
        case .folder:
            return "folder"
        case .markdownFile:
            return "doc.text"
        }
    }
}

struct CaptureDestination: Codable, Equatable, Hashable, Identifiable, Sendable {
    let relativePath: String
    let kind: CaptureDestinationKind
    let visibility: CaptureVisibility
    let title: String

    var id: String {
        "\(kind.rawValue):\(relativePath)"
    }

    var displayPath: String {
        relativePath.isEmpty ? "Vault root" : relativePath
    }

    /// The area name written into capture frontmatter and shown in the note.
    /// For the canonical `Areas/<Area>/...` layout this is the area folder;
    /// otherwise it falls back to the destination's visible title.
    var areaName: String {
        let components = relativePath.split(separator: "/").map(String.init)
        if let areasIndex = components.firstIndex(of: "Areas"),
           components.indices.contains(areasIndex + 1) {
            return components[areasIndex + 1]
        }

        if kind == .markdownFile, let fileName = components.last {
            return (fileName as NSString).deletingPathExtension
        }

        return title
    }

    var isFolder: Bool { kind == .folder }

    func resolved(in vaultRoot: URL) -> CaptureDestination {
        CaptureDestination(
            relativePath: relativePath,
            kind: kind,
            visibility: Self.inferVisibility(for: relativePath, vaultRoot: vaultRoot),
            title: title
        )
    }

    static func folder(
        relativePath: String,
        visibility: CaptureVisibility,
        title: String? = nil
    ) -> CaptureDestination {
        CaptureDestination(
            relativePath: relativePath,
            kind: .folder,
            visibility: visibility,
            title: title ?? URL(fileURLWithPath: relativePath).lastPathComponent
        )
    }

    static func markdownFile(
        relativePath: String,
        visibility: CaptureVisibility,
        title: String? = nil
    ) -> CaptureDestination {
        let lastPathComponent = URL(fileURLWithPath: relativePath).lastPathComponent
        let fallbackTitle = (lastPathComponent as NSString).deletingPathExtension
        return CaptureDestination(
            relativePath: relativePath,
            kind: .markdownFile,
            visibility: visibility,
            title: title ?? fallbackTitle
        )
    }

    static let blogs = folder(
        relativePath: "Areas/Blogs/Captures",
        visibility: .garden,
        title: "Blogs"
    )

    static let design = folder(
        relativePath: "Areas/Design & Interaction/Captures",
        visibility: .garden,
        title: "Design & Interaction"
    )

    static let productEngineering = folder(
        relativePath: "Areas/Product Engineering/Captures",
        visibility: .garden,
        title: "Product Engineering"
    )

    static let personal = folder(
        relativePath: "Areas/Personal/Captures",
        visibility: .privateArea,
        title: "Personal"
    )

    static let defaultFavorites = [design, blogs, productEngineering]

    static func inferVisibility(for relativePath: String) -> CaptureVisibility {
        // Without the vault contents available, default to private. A Garden
        // label is only safe when the selected area's map explicitly opts in.
        _ = relativePath
        return .privateArea
    }

    static func inferVisibility(for relativePath: String, vaultRoot: URL) -> CaptureVisibility {
        AreaVisibilityResolver.visibility(for: relativePath, vaultRoot: vaultRoot)
    }

    static func from(
        url: URL,
        vaultRoot: URL,
        kind: CaptureDestinationKind
    ) -> CaptureDestination? {
        guard url.isFileURL else {
            return nil
        }

        let standardizedRoot = VaultPathContainment.resolved(vaultRoot)
        let standardizedURL = VaultPathContainment.resolved(url)
        let rootPath = standardizedRoot.path.hasSuffix("/")
            ? standardizedRoot.path
            : standardizedRoot.path + "/"

        guard standardizedURL.path.hasPrefix(rootPath) else {
            return nil
        }

        let relativePath = String(standardizedURL.path.dropFirst(rootPath.count))
        guard let validatedPath = try? VaultPathValidator.validate(relativePath),
              !validatedPath.isEmpty else {
            return nil
        }

        if kind == .markdownFile {
            guard standardizedURL.pathExtension.lowercased() == "md" else {
                return nil
            }
            return .markdownFile(
                relativePath: validatedPath,
                visibility: inferVisibility(for: validatedPath, vaultRoot: standardizedRoot)
            )
        }

        return .folder(
            relativePath: validatedPath,
            visibility: inferVisibility(for: validatedPath, vaultRoot: standardizedRoot)
        )
    }
}

enum AreaVisibilityResolver {
    static func visibility(for relativePath: String, vaultRoot: URL) -> CaptureVisibility {
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count >= 2,
              components[0].caseInsensitiveCompare("Areas") == .orderedSame else {
            return .privateArea
        }

        let areaName = components[1]
        let resolvedRoot = VaultPathContainment.resolved(vaultRoot)
        let mapURL = resolvedRoot
            .appendingPathComponent("Areas", isDirectory: true)
            .appendingPathComponent(areaName, isDirectory: true)
            .appendingPathComponent("\(areaName).md")

        guard VaultPathContainment.contains(mapURL, inside: resolvedRoot),
              let text = try? String(contentsOf: mapURL, encoding: .utf8),
              let frontmatter = frontmatter(in: text),
              let visibility = frontmatterValue(named: "visibility", in: frontmatter),
              visibility.caseInsensitiveCompare("garden") == .orderedSame else {
            return .privateArea
        }

        return .garden
    }

    private static func frontmatter(in text: String) -> String? {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return nil
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return nil
        }

        return lines[1..<closingIndex].map(String.init).joined(separator: "\n")
    }

    private static func frontmatterValue(named name: String, in frontmatter: String) -> String? {
        for rawLine in frontmatter.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard key.caseInsensitiveCompare(name) == .orderedSame else {
                continue
            }

            let valueStart = line.index(after: separator)
            let value = line[valueStart...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

enum VaultPathContainment {
    static func resolved(_ url: URL) -> URL {
        let standardizedURL = url.standardizedFileURL
        var resolvedURL = URL(fileURLWithPath: "/", isDirectory: true)

        for component in standardizedURL.pathComponents where component != "/" {
            resolvedURL.appendPathComponent(component)
            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                resolvedURL = resolvedURL.resolvingSymlinksInPath().standardizedFileURL
            }
        }

        return resolvedURL.standardizedFileURL
    }

    static func contains(_ child: URL, inside root: URL, allowingRoot: Bool = false) -> Bool {
        let resolvedRoot = resolved(root)
        let resolvedChild = resolved(child)
        if allowingRoot && resolvedChild == resolvedRoot {
            return true
        }

        let rootPath = resolvedRoot.path.hasSuffix("/")
            ? resolvedRoot.path
            : resolvedRoot.path + "/"
        return resolvedChild.path.hasPrefix(rootPath)
    }
}

enum VaultPathValidator {
    static func validate(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureWriteError.invalidPathComponent(value)
        }

        guard !trimmed.hasPrefix("/"),
              !trimmed.hasSuffix("/"),
              !trimmed.contains("//") else {
            throw CaptureWriteError.invalidPathComponent(value)
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty, !components.contains(where: { $0.isEmpty }) else {
            throw CaptureWriteError.invalidPathComponent(value)
        }

        for component in components {
            _ = try VaultNameValidator.validate(String(component))
        }

        return components.map(String.init).joined(separator: "/")
    }
}

/// Persists the three quick folder destinations and any additional folders or
/// Markdown files selected from the capture UI. The list is deliberately small
/// and local-only: it contains relative paths, never vault contents.
@MainActor
final class DestinationStore: ObservableObject {
    private static let favoritesKey = "gardenDrop.destinationFavorites"
    private static let savedKey = "gardenDrop.savedDestinations"

    @Published private(set) var favorites: [CaptureDestination]
    @Published private(set) var savedDestinations: [CaptureDestination]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loadedFavorites = Self.load(CaptureDestination.self, key: Self.favoritesKey, defaults: defaults)
            .filter(\.isFolder)
            .prefix(3)
            .map { $0 }
        if loadedFavorites.isEmpty {
            loadedFavorites = CaptureDestination.defaultFavorites
        }
        self.favorites = loadedFavorites

        let storedDestinations = Self.load(CaptureDestination.self, key: Self.savedKey, defaults: defaults)
        self.savedDestinations = Self.unique(storedDestinations.filter { !loadedFavorites.contains($0) })

        if defaults.data(forKey: Self.favoritesKey) == nil {
            persistFavorites()
        }

        persistSavedDestinations()
    }

    var allDestinations: [CaptureDestination] {
        Self.unique(favorites + savedDestinations)
    }

    func setFavorite(_ destination: CaptureDestination, at index: Int) {
        guard destination.isFolder, (0..<3).contains(index) else {
            return
        }

        // A quick slot is a stable position. Ignore duplicate selections so a
        // user cannot accidentally collapse the remaining configured slots.
        if let existingIndex = favorites.firstIndex(of: destination), existingIndex != index {
            return
        }

        var next = favorites
        while next.count <= index {
            next.append(CaptureDestination.defaultFavorites[min(next.count, CaptureDestination.defaultFavorites.count - 1)])
        }
        next[index] = destination
        favorites = Self.unique(next).filter(\.isFolder).prefix(3).map { $0 }
        savedDestinations.removeAll { $0 == destination }
        persistFavorites()
        persistSavedDestinations()
    }

    func removeFavorite(at index: Int) {
        guard favorites.indices.contains(index) else {
            return
        }

        favorites.remove(at: index)
        persistFavorites()
    }

    func remember(_ destination: CaptureDestination) {
        guard !favorites.contains(destination) else {
            return
        }
        savedDestinations = Self.unique(savedDestinations + [destination])
        persistSavedDestinations()
    }

    func forget(_ destination: CaptureDestination) {
        guard !favorites.contains(destination) else {
            return
        }
        savedDestinations.removeAll { $0 == destination }
        persistSavedDestinations()
    }

    func refreshVisibility(for vaultRoot: URL) {
        let refreshedFavorites = favorites.map { $0.resolved(in: vaultRoot) }
        let refreshedSaved = savedDestinations.map { $0.resolved(in: vaultRoot) }
        favorites = Self.unique(refreshedFavorites).filter(\.isFolder).prefix(3).map { $0 }
        savedDestinations = Self.unique(refreshedSaved.filter { !favorites.contains($0) })
        persistFavorites()
        persistSavedDestinations()
    }

    private func persistFavorites() {
        Self.save(favorites, key: Self.favoritesKey, defaults: defaults)
    }

    private func persistSavedDestinations() {
        Self.save(savedDestinations, key: Self.savedKey, defaults: defaults)
    }

    private static func unique(_ destinations: [CaptureDestination]) -> [CaptureDestination] {
        var seen = Set<String>()
        return destinations.filter { seen.insert($0.id).inserted }
    }

    private static func load<T: Decodable>(
        _ type: T.Type,
        key: String,
        defaults: UserDefaults
    ) -> [T] {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([T].self, from: data) else {
            return []
        }
        return values
    }

    private static func save<T: Encodable>(
        _ values: [T],
        key: String,
        defaults: UserDefaults
    ) {
        guard let data = try? JSONEncoder().encode(values) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

/// A tiny wrapper around security-scoped bookmarks. Garden Drop is not sandbox
/// entitlements-bound in its current local DMG, but storing the bookmark now
/// means a sandboxed/notarized build can keep the same settings contract.
struct VaultBookmarkStore {
    static let bookmarkKey = "gardenDrop.vaultBookmark"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: Self.bookmarkKey)
    }

    func resolve() -> URL? {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ),
              url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        if isStale {
            try? save(url: url)
        }
        return url
    }

    func remove() {
        defaults.removeObject(forKey: Self.bookmarkKey)
    }
}

enum DestinationPicker {
    @MainActor
    static func choose(
        kind: CaptureDestinationKind,
        vaultRoot: URL
    ) -> CaptureDestination? {
        let accessStarted = vaultRoot.startAccessingSecurityScopedResource()
        defer {
            if accessStarted {
                vaultRoot.stopAccessingSecurityScopedResource()
            }
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = kind == .folder
        panel.canChooseFiles = kind == .markdownFile
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = kind == .folder
        panel.prompt = kind == .folder ? "Use Folder" : "Use Markdown File"
        panel.message = kind == .folder
            ? "Choose a folder inside your Obsidian vault."
            : "Choose a Markdown file inside your Obsidian vault."
        panel.directoryURL = vaultRoot

        guard panel.runModal() == .OK,
              let url = panel.url,
              let destination = CaptureDestination.from(
                url: url,
                vaultRoot: vaultRoot,
                kind: kind
              ) else {
            return nil
        }
        return destination
    }
}
