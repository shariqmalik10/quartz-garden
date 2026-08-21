import XCTest
@testable import GardenDrop

@MainActor
final class GardenDropCoordinatorTests: XCTestCase {
    func testMenuBarItemRemainsInstalledWhenNotchIsToggled() {
        let suiteName = "GardenDropCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = GardenDropCoordinator(defaults: defaults)
        coordinator.start()
        XCTAssertTrue(coordinator.isMenuBarItemInstalled)
        XCTAssertEqual(coordinator.surfaceMode, .menuBar)

        coordinator.setNotchEnabled(true)
        XCTAssertTrue(coordinator.isMenuBarItemInstalled)
        XCTAssertEqual(coordinator.surfaceMode, .both)

        coordinator.setNotchEnabled(false)
        XCTAssertTrue(coordinator.isMenuBarItemInstalled)
        XCTAssertEqual(coordinator.surfaceMode, .menuBar)
        coordinator.stop()
    }

    func testLegacyNotchOnlyPreferenceMigratesToBoth() {
        let suiteName = "GardenDropCoordinatorMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("notch", forKey: "gardenDrop.surfaceMode")

        let coordinator = GardenDropCoordinator(defaults: defaults)

        XCTAssertEqual(coordinator.surfaceMode, .both)
        XCTAssertEqual(defaults.string(forKey: "gardenDrop.surfaceMode"), "both")
    }
}
