import XCTest
@testable import GardenDrop

final class CaptureSurfaceModeTests: XCTestCase {
    func testSurfaceModesExposeTheExpectedEntrances() {
        XCTAssertFalse(CaptureSurfaceMode.menuBar.showsNotch)
        XCTAssertTrue(CaptureSurfaceMode.menuBar.showsMenuBar)

        XCTAssertTrue(CaptureSurfaceMode.both.showsNotch)
        XCTAssertTrue(CaptureSurfaceMode.both.showsMenuBar)
    }

    func testSurfaceModesHaveStablePersistedValues() {
        XCTAssertEqual(CaptureSurfaceMode.menuBar.rawValue, "menuBar")
        XCTAssertEqual(CaptureSurfaceMode.both.rawValue, "both")
        XCTAssertEqual(CaptureSurfaceMode(rawValue: "both"), .both)
    }

    func testLegacyNotchPreferenceMigratesToBothSurfaces() {
        XCTAssertEqual(CaptureSurfaceMode.migrated(from: "notch"), .both)
        XCTAssertEqual(CaptureSurfaceMode.migrated(from: "both"), .both)
        XCTAssertEqual(CaptureSurfaceMode.migrated(from: "menuBar"), .menuBar)
        XCTAssertEqual(CaptureSurfaceMode.migrated(from: nil), .menuBar)
    }
}
