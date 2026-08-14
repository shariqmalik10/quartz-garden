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
}
