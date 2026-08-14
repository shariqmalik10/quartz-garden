import XCTest
@testable import GardenDrop

@MainActor
final class CaptureComposerModelTests: XCTestCase {
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
