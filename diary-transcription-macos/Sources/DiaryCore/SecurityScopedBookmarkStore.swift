import Foundation

public final class VaultAccess {
    public let url: URL
    private let didStartSecurityScope: Bool

    init(url: URL, didStartSecurityScope: Bool) {
        self.url = url
        self.didStartSecurityScope = didStartSecurityScope
    }

    deinit {
        if didStartSecurityScope {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

public final class SecurityScopedBookmarkStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "DiaryTranscription.vaultSecurityScopedBookmark"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var hasBookmark: Bool {
        defaults.data(forKey: key) != nil
    }

    @discardableResult
    public func saveAndAccess(_ url: URL) throws -> VaultAccess {
        let normalizedURL = url.standardizedFileURL
        let data: Data
        do {
            data = try normalizedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw DiaryError.bookmarkCreationFailed
        }
        defaults.set(data, forKey: key)
        return VaultAccess(
            url: normalizedURL,
            didStartSecurityScope: normalizedURL.startAccessingSecurityScopedResource()
        )
    }

    public func restoreAccess() throws -> VaultAccess {
        guard let data = defaults.data(forKey: key) else {
            throw DiaryError.bookmarkMissing
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL
        } catch {
            throw DiaryError.bookmarkResolutionFailed
        }

        if isStale {
            _ = try saveAndAccess(url)
        }
        return VaultAccess(
            url: url,
            didStartSecurityScope: url.startAccessingSecurityScopedResource()
        )
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
