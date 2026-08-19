import XCTest
@testable import GardenDrop

@MainActor
final class DestinationStoreTests: XCTestCase {
    func testDefaultsIncludeBlogsAsAQuickGardenDestination() {
        let suiteName = "GardenDropDestinationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DestinationStore(defaults: defaults)

        XCTAssertEqual(store.favorites.count, 3)
        XCTAssertTrue(store.favorites.contains(CaptureDestination.blogs))
        XCTAssertEqual(CaptureDestination.blogs.visibility, .garden)
        XCTAssertEqual(CaptureDestination.blogs.relativePath, "Areas/Blogs/Captures")
    }

    func testFavoritesAndAdditionalFileDestinationsPersist() {
        let suiteName = "GardenDropDestinationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customFolder = CaptureDestination.folder(
            relativePath: "Areas/Blogs/Longform",
            visibility: .garden,
            title: "Longform"
        )
        let customFile = CaptureDestination.markdownFile(
            relativePath: "Areas/Blogs/Blogs.md",
            visibility: .garden,
            title: "Blogs I return to"
        )

        let store = DestinationStore(defaults: defaults)
        store.setFavorite(customFolder, at: 0)
        store.remember(customFile)

        let restored = DestinationStore(defaults: defaults)
        XCTAssertEqual(restored.favorites.first, customFolder)
        XCTAssertTrue(restored.savedDestinations.contains(customFile))
        XCTAssertTrue(restored.allDestinations.contains(customFile))
    }

    func testDestinationFromURLStaysInsideVaultAndInfersPrivacy() throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropDestinationTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)

        let publicFolder = vaultURL.appendingPathComponent("Areas/Blogs/Captures", isDirectory: true)
        let privateFolder = vaultURL.appendingPathComponent("Private/Reading", isDirectory: true)

        let publicDestination = try XCTUnwrap(
            CaptureDestination.from(url: publicFolder, vaultRoot: vaultURL, kind: .folder)
        )
        let privateDestination = try XCTUnwrap(
            CaptureDestination.from(url: privateFolder, vaultRoot: vaultURL, kind: .folder)
        )

        XCTAssertEqual(publicDestination.visibility, .garden)
        XCTAssertEqual(privateDestination.visibility, .privateArea)
        XCTAssertNil(
            CaptureDestination.from(
                url: vaultURL.deletingLastPathComponent().appendingPathComponent("outside"),
                vaultRoot: vaultURL,
                kind: .folder
            )
        )
    }

}
