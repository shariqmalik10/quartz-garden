import XCTest
@testable import GardenDrop

@MainActor
final class VaultConfigurationTests: XCTestCase {
    func testRuntimeWithoutBookmarkIsUnconfiguredInsteadOfFixtureWritable() throws {
        if let configuredPath = ProcessInfo.processInfo.environment["GARDEN_DROP_VAULT"],
           !configuredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw XCTSkip("GARDEN_DROP_VAULT is set for this test process")
        }

        let suiteName = "GardenDropVaultRuntimeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = VaultConfiguration.runtime(
            bookmarkStore: VaultBookmarkStore(defaults: defaults)
        )

        XCTAssertFalse(configuration.isConfigured)
        XCTAssertTrue(configuration.isFixture)
        XCTAssertEqual(configuration.displayName, "No vault selected")
    }

    func testUnconfiguredComposerRefusesToWriteIntoPlaceholderPath() {
        let placeholderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropUnconfigured-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration.unconfigured(at: placeholderURL)
        let model = CaptureComposerModel(
            source: .blank,
            vaultConfiguration: configuration
        )

        model.thought = "This must wait for an explicit vault selection."
        model.save()

        XCTAssertEqual(
            model.state,
            .error("Choose an Obsidian vault in Settings before saving.")
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: placeholderURL.path))
    }

    func testWriterRejectsAnUnconfiguredVaultEvenWhenCalledDirectly() async throws {
        let placeholderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropWriterUnconfigured-\(UUID().uuidString)", isDirectory: true)
        let draft = CaptureDraft(
            id: "gd-20260821-unconfigured",
            title: "Unconfigured",
            source: .sample,
            thought: "This must not be written.",
            areaName: "Blogs",
            visibility: .garden,
            capturedAt: Date(),
            metadataStatus: .complete
        )

        do {
            _ = try await CaptureWriter(
                vaultRoot: placeholderURL,
                isConfigured: false
            ).write(draft)
            XCTFail("Expected the writer to reject an unconfigured vault")
        } catch let error as CaptureWriteError {
            XCTAssertEqual(error, .vaultNotConfigured)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: placeholderURL.path))
    }
}
