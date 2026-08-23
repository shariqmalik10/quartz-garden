import Foundation
import XCTest
@testable import DiaryCore

final class SecurityScopedBookmarkStoreTests: XCTestCase {
    func testBookmarkPersistsAcrossStoreInstancesAndCanBeCleared() throws {
        let suiteName = "DiaryCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstStore = SecurityScopedBookmarkStore(defaults: defaults, key: "vault")
        _ = try firstStore.saveAndAccess(directory)
        XCTAssertTrue(firstStore.hasBookmark)

        let secondStore = SecurityScopedBookmarkStore(defaults: defaults, key: "vault")
        let restored = try secondStore.restoreAccess()
        XCTAssertEqual(restored.url.standardizedFileURL, directory.standardizedFileURL)

        secondStore.clear()
        XCTAssertFalse(firstStore.hasBookmark)
        XCTAssertThrowsError(try firstStore.restoreAccess()) { error in
            XCTAssertEqual(error as? DiaryError, .bookmarkMissing)
        }
    }
}
