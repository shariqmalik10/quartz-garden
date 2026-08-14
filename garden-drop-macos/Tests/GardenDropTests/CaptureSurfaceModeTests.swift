import XCTest
@testable import GardenDrop

final class CaptureSurfaceModeTests: XCTestCase {
    func testSurfaceModesExposeTheExpectedEntrances() {
        XCTAssertTrue(CaptureSurfaceMode.notch.showsNotch)
        XCTAssertFalse(CaptureSurfaceMode.notch.showsMenuBar)

        XCTAssertFalse(CaptureSurfaceMode.menuBar.showsNotch)
        XCTAssertTrue(CaptureSurfaceMode.menuBar.showsMenuBar)

        XCTAssertTrue(CaptureSurfaceMode.both.showsNotch)
        XCTAssertTrue(CaptureSurfaceMode.both.showsMenuBar)
    }

    func testSurfaceModesHaveStablePersistedValues() {
        XCTAssertEqual(CaptureSurfaceMode.notch.rawValue, "notch")
        XCTAssertEqual(CaptureSurfaceMode.menuBar.rawValue, "menuBar")
        XCTAssertEqual(CaptureSurfaceMode.both.rawValue, "both")
        XCTAssertEqual(CaptureSurfaceMode(rawValue: "both"), .both)
    }
}
