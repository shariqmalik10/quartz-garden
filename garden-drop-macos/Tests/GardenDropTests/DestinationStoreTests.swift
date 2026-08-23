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

    func testChoosingAnExistingQuickDestinationDoesNotCollapseSlots() {
        let suiteName = "GardenDropDuplicateFavoriteTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DestinationStore(defaults: defaults)
        let original = store.favorites

        store.setFavorite(original[0], at: 1)

        XCTAssertEqual(store.favorites, original)
        XCTAssertEqual(store.favorites.count, 3)
    }

    func testLastUsedSavedFolderPersistsAcrossStoreRelaunchAndFallsBackWhenRemoved() throws {
        let suiteName = "GardenDropLastUsedDestinationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customFolder = CaptureDestination.folder(
            relativePath: "Areas/Blogs/Longform",
            visibility: .garden,
            title: "Longform"
        )
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropLastUsedFolderVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        try FileManager.default.createDirectory(
            at: vaultURL.appendingPathComponent(customFolder.relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
        let store = DestinationStore(defaults: defaults)
        store.remember(customFolder)
        store.markLastUsed(customFolder)

        let restored = DestinationStore(defaults: defaults)
        XCTAssertEqual(restored.lastUsedDestination?.id, customFolder.id)
        XCTAssertEqual(
            restored.defaultDestination(in: vaultURL).id,
            customFolder.id
        )

        restored.forget(customFolder)
        XCTAssertEqual(
            restored.defaultDestination(in: vaultURL).id,
            restored.favorites[0].id
        )
    }

    func testLastUsedQuickFolderPersistsAcrossStoreRelaunch() throws {
        let suiteName = "GardenDropLastUsedQuickDestinationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropLastUsedQuickVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let store = DestinationStore(defaults: defaults)
        let quickDestination = store.favorites[1]
        try FileManager.default.createDirectory(
            at: vaultURL.appendingPathComponent(quickDestination.relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
        store.markLastUsed(quickDestination)

        let restored = DestinationStore(defaults: defaults)
        XCTAssertEqual(restored.defaultDestination(in: vaultURL).id, quickDestination.id)
    }

    func testLastUsedSavedMarkdownFilePersistsAcrossStoreRelaunch() throws {
        let suiteName = "GardenDropLastUsedMarkdownDestinationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropLastUsedMarkdownVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let destination = CaptureDestination.markdownFile(
            relativePath: "Areas/Reading/Reading.md",
            visibility: .privateArea,
            title: "Reading"
        )
        let fileURL = vaultURL.appendingPathComponent(destination.relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("# Reading\n".utf8).write(to: fileURL)

        let store = DestinationStore(defaults: defaults)
        store.remember(destination)
        store.markLastUsed(destination)

        let restored = DestinationStore(defaults: defaults)
        XCTAssertEqual(restored.defaultDestination(in: vaultURL).id, destination.id)
    }

    func testDeletedLastUsedFolderAndEscapingPathFallBackSafely() throws {
        let suiteName = "GardenDropStaleLastUsedTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropStaleVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)

        let deletedFolder = CaptureDestination.folder(
            relativePath: "Areas/Deleted/Captures",
            visibility: .garden,
            title: "Deleted"
        )
        let store = DestinationStore(defaults: defaults)
        store.remember(deletedFolder)
        store.markLastUsed(deletedFolder)
        XCTAssertNotEqual(store.defaultDestination(in: vaultURL).id, deletedFolder.id)

        let escaping = CaptureDestination.folder(
            relativePath: "../Outside",
            visibility: .garden,
            title: "Outside"
        )
        store.remember(escaping)
        store.markLastUsed(escaping)
        XCTAssertNotEqual(store.defaultDestination(in: vaultURL).id, escaping.id)
    }

    func testVisibilityRefreshKeepsLastUsedDestinationIdentity() throws {
        let suiteName = "GardenDropLastUsedVisibilityTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropVisibilityRefreshVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let destination = CaptureDestination.folder(
            relativePath: "Areas/Writing/Captures",
            visibility: .privateArea,
            title: "Captures"
        )
        try FileManager.default.createDirectory(
            at: vaultURL.appendingPathComponent(destination.relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
        let mapURL = vaultURL.appendingPathComponent("Areas/Writing/Writing.md")
        try Data("---\nvisibility: garden\n---\n".utf8).write(to: mapURL)

        let store = DestinationStore(defaults: defaults)
        store.remember(destination)
        store.markLastUsed(destination)
        store.refreshVisibility(for: vaultURL)

        let restored = DestinationStore(defaults: defaults)
        let selected = restored.defaultDestination(in: vaultURL)
        XCTAssertEqual(selected.id, destination.id)
        XCTAssertEqual(selected.visibility, .garden)
    }

    func testDestinationFromURLStaysInsideVaultAndInfersPrivacy() throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropDestinationTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)

        let publicFolder = vaultURL.appendingPathComponent("Areas/Blogs/Captures", isDirectory: true)
        let privateFolder = vaultURL.appendingPathComponent("Private/Reading", isDirectory: true)
        let blogsMapURL = vaultURL.appendingPathComponent("Areas/Blogs/Blogs.md")
        try FileManager.default.createDirectory(
            at: blogsMapURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("---\nkind: area\nvisibility: garden\n---\n".utf8).write(to: blogsMapURL)

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

    func testMissingOrInvalidAreaMapsDefaultToPrivateIncludingMarkdownFiles() throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropVisibilityTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let missingMapFolder = vaultURL.appendingPathComponent("Areas/Unmapped/Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: missingMapFolder, withIntermediateDirectories: true)
        let missingDestination = try XCTUnwrap(
            CaptureDestination.from(url: missingMapFolder, vaultRoot: vaultURL, kind: .folder)
        )
        XCTAssertEqual(missingDestination.visibility, .privateArea)

        let invalidMapURL = vaultURL.appendingPathComponent("Areas/Invalid/Invalid.md")
        try FileManager.default.createDirectory(
            at: invalidMapURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("---\nkind: area\nvisibility: maybe\n---\n".utf8).write(to: invalidMapURL)

        let invalidFile = try XCTUnwrap(
            CaptureDestination.from(url: invalidMapURL, vaultRoot: vaultURL, kind: .markdownFile)
        )
        XCTAssertEqual(invalidFile.visibility, .privateArea)
    }

    func testDestinationPickerModelRejectsSymlinkThatEscapesVault() throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropSymlinkVault-\(UUID().uuidString)", isDirectory: true)
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropSymlinkOutside-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: outsideURL)
        }
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)

        let linkURL = vaultURL.appendingPathComponent("Areas", isDirectory: true)
        try FileManager.default.createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: outsideURL
        )

        XCTAssertNil(
            CaptureDestination.from(
                url: linkURL.appendingPathComponent("Blogs/Captures", isDirectory: true),
                vaultRoot: vaultURL,
                kind: .folder
            )
        )
    }

}
