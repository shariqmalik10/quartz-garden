import XCTest
@testable import GardenDrop

@MainActor
final class CaptureComposerModelTests: XCTestCase {
    func testBlankComposerStartsEmptyAndFocusesSource() {
        let model = CaptureComposerModel(source: .blank)

        XCTAssertEqual(model.state, .empty)
        XCTAssertEqual(model.initialFocusTarget, .source)
        XCTAssertFalse(model.hasSource)
        XCTAssertFalse(model.isDirty)
    }

    func testExistingSourceStartsPreparedAndFocusesThought() {
        let model = CaptureComposerModel(source: .sample)

        XCTAssertEqual(model.state, .prepared)
        XCTAssertEqual(model.initialFocusTarget, .thought)
        XCTAssertTrue(model.hasSource)
        XCTAssertFalse(model.isDirty)
    }

    func testDirtyStateTracksDraftAndClearRestoresTheInitialState() {
        let model = CaptureComposerModel(source: .blank)

        model.thought = "A thought worth keeping."

        XCTAssertEqual(model.state, .prepared)
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(model.hasUnsavedChanges)

        model.clearCapture()

        XCTAssertEqual(model.state, .empty)
        XCTAssertFalse(model.isDirty)
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testWriteFailurePreservesDraftContentAndEntersErrorState() async throws {
        let invalidVaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropInvalidVault-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: invalidVaultURL) }
        try Data("not a directory".utf8).write(to: invalidVaultURL)

        let model = CaptureComposerModel(
            source: .blank,
            vaultConfiguration: VaultConfiguration(rootURL: invalidVaultURL)
        )
        model.thought = "Keep this thought if the write fails."
        model.save()

        for _ in 0..<40 {
            if case .error(let message) = model.state {
                XCTAssertFalse(message.isEmpty)
                XCTAssertEqual(model.thought, "Keep this thought if the write fails.")
                XCTAssertTrue(model.isDirty)
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        XCTFail("The failed capture did not reach the error state within the test window.")
    }

    func testSavesUserEnteredLinkToTheConfiguredVault() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropComposerTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let model = CaptureComposerModel(
            vaultConfiguration: VaultConfiguration(rootURL: vaultURL)
        )
        model.linkText = "https://openai.com/research"
        model.thought = "A link worth revisiting."

        XCTAssertTrue(model.hasValidLink)
        XCTAssertEqual(model.activeSource.url?.absoluteString, "https://openai.com/research")

        model.save()

        for _ in 0..<40 {
            switch model.status {
            case .saved(let result):
                XCTAssertEqual(model.state, .done(result))
                XCTAssertFalse(model.isDirty)
                let markdown = try String(contentsOf: result.noteURL, encoding: .utf8)
                XCTAssertTrue(markdown.contains("source: \"https://openai.com/research\""))
                XCTAssertTrue(markdown.contains("A link worth revisiting."))
                return
            case .failed(let message):
                XCTFail("The link capture failed: \(message)")
                return
            case .idle, .saving:
                try await Task.sleep(for: .milliseconds(25))
            }
        }

        XCTFail("The link capture did not finish within the test window.")
    }

    func testBlogsDestinationWritesIntoTheCanonicalBlogsCaptureFolder() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropBlogsTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let blogsMapURL = vaultURL.appendingPathComponent("Areas/Blogs/Blogs.md")
        try FileManager.default.createDirectory(
            at: blogsMapURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("---\nkind: area\nvisibility: garden\n---\n\n# Blogs\n".utf8)
            .write(to: blogsMapURL)

        let suiteName = "GardenDropBlogsDestinationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DestinationStore(defaults: defaults)
        let model = CaptureComposerModel(
            source: .blank,
            vaultConfiguration: VaultConfiguration(rootURL: vaultURL),
            destinationStore: store
        )
        model.chooseDestination(CaptureDestination.blogs)
        model.linkText = "https://example.com/a-blog"
        model.thought = "A long-form piece worth revisiting."
        model.save()

        for _ in 0..<40 {
            switch model.status {
            case .saved(let result):
                XCTAssertTrue(result.noteURL.path.contains("Areas/Blogs/Captures"))
                let markdown = try String(contentsOf: result.noteURL, encoding: .utf8)
                XCTAssertTrue(markdown.contains("area: \"[[Blogs]]\""))
                XCTAssertTrue(markdown.contains("visibility: garden"))
                return
            case .failed(let message):
                XCTFail("The blog link capture failed: \(message)")
                return
            case .idle, .saving:
                try await Task.sleep(for: .milliseconds(25))
            }
        }

        XCTFail("The blog link capture did not finish within the test window.")
    }

    func testUpdatingVaultConfigurationRefreshesTheExistingComposerWriter() async throws {
        let firstVault = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropOldVault-\(UUID().uuidString)", isDirectory: true)
        let secondVault = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropNewVault-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: firstVault)
            try? FileManager.default.removeItem(at: secondVault)
        }

        let blogsMapURL = secondVault.appendingPathComponent("Areas/Blogs/Blogs.md")
        try FileManager.default.createDirectory(
            at: blogsMapURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("---\nkind: area\nvisibility: garden\n---\n".utf8).write(to: blogsMapURL)

        let suiteName = "GardenDropComposerVaultRefreshTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DestinationStore(defaults: defaults)
        let model = CaptureComposerModel(
            source: .blank,
            vaultConfiguration: VaultConfiguration(rootURL: firstVault),
            destinationStore: store
        )
        model.chooseDestination(CaptureDestination.blogs)
        model.updateVaultConfiguration(VaultConfiguration(rootURL: secondVault))
        model.linkText = "https://example.com/refreshed"
        model.thought = "This must use the newly selected vault."
        model.save()

        for _ in 0..<40 {
            switch model.status {
            case .saved(let result):
                XCTAssertTrue(result.noteURL.path.hasPrefix(secondVault.path))
                XCTAssertFalse(FileManager.default.fileExists(atPath: firstVault.appendingPathComponent("Areas").path))
                let markdown = try String(contentsOf: result.noteURL, encoding: .utf8)
                XCTAssertTrue(markdown.contains("visibility: garden"))
                return
            case .failed(let message):
                XCTFail("The refreshed-vault capture failed: \(message)")
                return
            case .idle, .saving:
                try await Task.sleep(for: .milliseconds(25))
            }
        }

        XCTFail("The refreshed-vault capture did not finish within the test window.")
    }

    func testSavesHandEnteredNoteWithoutALink() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropNoteTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let model = CaptureComposerModel(
            source: .blank,
            vaultConfiguration: VaultConfiguration(rootURL: vaultURL)
        )
        model.draftInput = "A note dropped straight into the garden."
        model.commitDraftInput()

        XCTAssertFalse(model.hasValidLink)
        XCTAssertTrue(model.hasCaptureContent)

        model.save()

        for _ in 0..<40 {
            switch model.status {
            case .saved(let result):
                let markdown = try String(contentsOf: result.noteURL, encoding: .utf8)
                XCTAssertTrue(markdown.contains("title: \"A note dropped straight into the garden.\""))
                XCTAssertTrue(markdown.contains("Captured from the clipboard."))
                return
            case .failed(let message):
                XCTFail("The note capture failed: \(message)")
                return
            case .idle, .saving:
                try await Task.sleep(for: .milliseconds(25))
            }
        }

        XCTFail("The note capture did not finish within the test window.")
    }

    func testSavesDroppedFileAsAnAttachment() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropFileTest-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropAttachment-\(UUID().uuidString).txt")
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: sourceURL)
        }
        try Data("Dropped text".utf8).write(to: sourceURL)

        let model = CaptureComposerModel(
            source: .blank,
            vaultConfiguration: VaultConfiguration(rootURL: vaultURL)
        )
        model.acceptDroppedFile(sourceURL)

        XCTAssertEqual(model.activeSource.attachment?.fileName, sourceURL.lastPathComponent)
        XCTAssertTrue(model.canPlant)

        model.save()

        for _ in 0..<40 {
            switch model.status {
            case .saved(let result):
                let attachmentURL = try XCTUnwrap(result.attachmentURL)
                XCTAssertEqual(
                    try Data(contentsOf: attachmentURL),
                    Data("Dropped text".utf8)
                )
                return
            case .failed(let message):
                XCTFail("The file capture failed: \(message)")
                return
            case .idle, .saving:
                try await Task.sleep(for: .milliseconds(25))
            }
        }

        XCTFail("The file capture did not finish within the test window.")
    }
}
