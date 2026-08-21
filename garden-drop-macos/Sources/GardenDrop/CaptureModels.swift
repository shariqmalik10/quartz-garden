import Foundation

enum CaptureVisibility: String, CaseIterable, Codable, Identifiable, Sendable {
    case garden
    case privateArea = "private"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .garden:
            return "Garden"
        case .privateArea:
            return "Private"
        }
    }

    var actionTitle: String {
        switch self {
        case .garden:
            return "Save to Garden"
        case .privateArea:
            return "Save Privately"
        }
    }

    var symbolName: String {
        switch self {
        case .garden:
            return "globe"
        case .privateArea:
            return "lock"
        }
    }
}

enum CaptureSourceType: String, Codable, Sendable {
    case web
    case image
    case text

    var displayName: String {
        switch self {
        case .web:
            return "Link"
        case .image:
            return "Image"
        case .text:
            return "Text"
        }
    }
}

enum MetadataStatus: String, Codable, Sendable {
    case complete
    case pending
    case failed
}

struct CaptureAttachment: Equatable, Sendable {
    let fileName: String
    let data: Data
    let mimeType: String?
}

struct CaptureSource: Equatable, Sendable {
    let type: CaptureSourceType
    var title: String
    let url: URL?
    let domain: String?
    let excerpt: String?
    let capturedText: String?
    let attachment: CaptureAttachment?

    static let blank = CaptureSource(
        type: .text,
        title: "New note",
        url: nil,
        domain: nil,
        excerpt: nil,
        capturedText: nil,
        attachment: nil
    )

    static let sample = CaptureSource(
        type: .web,
        title: "A small link, ready to plant",
        url: URL(string: "https://example.com/field-note"),
        domain: "example.com",
        excerpt: "The first local capture should feel quiet, immediate, and easy to find again.",
        capturedText: nil,
        attachment: nil
    )
}

struct CaptureDraft: Equatable, Sendable {
    let id: String
    let title: String
    let source: CaptureSource
    let thought: String
    let areaName: String
    let visibility: CaptureVisibility
    let destination: CaptureDestination
    let capturedAt: Date
    let metadataStatus: MetadataStatus

    init(
        id: String,
        title: String,
        source: CaptureSource,
        thought: String,
        areaName: String,
        visibility: CaptureVisibility,
        capturedAt: Date,
        metadataStatus: MetadataStatus
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.thought = thought
        self.areaName = areaName
        self.visibility = visibility
        self.destination = .folder(
            relativePath: "Areas/\(areaName)/Captures",
            visibility: visibility,
            title: areaName
        )
        self.capturedAt = capturedAt
        self.metadataStatus = metadataStatus
    }

    init(
        id: String,
        title: String,
        source: CaptureSource,
        thought: String,
        destination: CaptureDestination,
        capturedAt: Date,
        metadataStatus: MetadataStatus
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.thought = thought
        self.areaName = destination.areaName
        self.visibility = destination.visibility
        self.destination = destination
        self.capturedAt = capturedAt
        self.metadataStatus = metadataStatus
    }
}

struct CaptureResult: Equatable, Sendable {
    let noteURL: URL
    let attachmentURL: URL?
}

struct AreaOption: Hashable, Identifiable, Sendable {
    let name: String
    let visibility: CaptureVisibility

    var destination: CaptureDestination {
        .folder(
            relativePath: "Areas/\(name)/Captures",
            visibility: visibility,
            title: name
        )
    }

    var id: String {
        "\(visibility.rawValue):\(name)"
    }

    static let defaults = [
        AreaOption(name: "Design & Interaction", visibility: .garden),
        AreaOption(name: "Blogs", visibility: .garden),
        AreaOption(name: "Product Engineering", visibility: .garden),
        AreaOption(name: "Personal", visibility: .privateArea),
    ]
}

enum CaptureID {
    static func make(date: Date = Date(), suffix: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"

        let generatedSuffix = suffix ?? String(UUID().uuidString.prefix(6)).lowercased()
        return "gd-\(formatter.string(from: date))-\(generatedSuffix)"
    }
}

struct VaultConfiguration: Equatable, Sendable {
    let rootURL: URL
    /// A runtime vault is configured only after an explicit environment
    /// override or a security-scoped bookmark has been validated. Keeping the
    /// URL non-optional lets the existing destination model remain simple,
    /// while this flag prevents the fixture path from ever becoming a write
    /// target in production.
    let isConfigured: Bool

    init(rootURL: URL) {
        self.init(rootURL: rootURL, isConfigured: true)
    }

    private init(rootURL: URL, isConfigured: Bool) {
        self.rootURL = rootURL
        self.isConfigured = isConfigured
    }

    static var runtime: VaultConfiguration {
        runtime(bookmarkStore: VaultBookmarkStore())
    }

    static func runtime(bookmarkStore: VaultBookmarkStore) -> VaultConfiguration {
        if let configuredPath = ProcessInfo.processInfo.environment["GARDEN_DROP_VAULT"],
           !configuredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(
                fileURLWithPath: configuredPath.trimmingCharacters(in: .whitespacesAndNewlines),
                isDirectory: true
            )
            return isDirectory(url) ? VaultConfiguration(rootURL: url) : .unconfigured
        }

        if let bookmarkedURL = bookmarkStore.resolve() {
            return isDirectory(bookmarkedURL)
                ? VaultConfiguration(rootURL: bookmarkedURL)
                : .unconfigured
        }

        // A missing bookmark is a setup state, not permission to write to a
        // test fixture. The fixture-shaped URL is retained only as a harmless
        // placeholder for destination calculations and diagnostics.
        return .unconfigured
    }

    static var unconfigured: VaultConfiguration {
        unconfigured(at: fixtureURL)
    }

    static func unconfigured(at rootURL: URL) -> VaultConfiguration {
        VaultConfiguration(rootURL: rootURL, isConfigured: false)
    }

    /// Explicit opt-in for unit tests and local fixtures. Production runtime
    /// resolution never calls this factory.
    static func fixtureForTesting(at rootURL: URL? = nil) -> VaultConfiguration {
        VaultConfiguration(rootURL: rootURL ?? fixtureURL)
    }

    private static var fixtureURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropFixtureVault", isDirectory: true)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
    }

    var isFixture: Bool {
        rootURL.standardizedFileURL == Self.fixtureURL.standardizedFileURL
    }

    var displayName: String {
        guard isConfigured else {
            return "No vault selected"
        }
        if isFixture {
            return "Fixture vault · local only"
        }
        return rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent
    }
}

enum VaultNameValidator {
    static func validate(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureWriteError.invalidPathComponent(value)
        }

        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: invalidCharacters) == nil,
              trimmed.rangeOfCharacter(from: .controlCharacters) == nil,
              trimmed != ".",
              trimmed != ".." else {
            throw CaptureWriteError.invalidPathComponent(value)
        }

        return trimmed
    }
}
