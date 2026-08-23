import AppKit
import XCTest
@testable import GardenDrop

@MainActor
final class GardenDropRuntimeIntegrationTests: XCTestCase {
    func testRealMenuBarCaptureSettingsAndNotchControllersWorkTogether() throws {
        let suiteName = "GardenDropRuntimeIntegrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = GardenDropCoordinator(defaults: defaults)
        defer { coordinator.stop() }

        coordinator.start()
        XCTAssertTrue(coordinator.isMenuBarItemInstalled)

        let menu = try XCTUnwrap(coordinator.statusMenu)
        try performMenuItem(named: "New Capture…", in: menu)
        XCTAssertEqual(
            NSApp.windows.filter { $0.title == "Garden Drop" && $0.isVisible }.count,
            1
        )

        try performMenuItem(named: "Settings…", in: menu)
        let settingsIdentifier = NSUserInterfaceItemIdentifier("GardenDrop.Settings")
        let firstSettingsWindow = try XCTUnwrap(
            NSApp.windows.first { $0.identifier == settingsIdentifier }
        )
        XCTAssertTrue(firstSettingsWindow.isVisible)

        // Repeated requests must bring forward the retained window, not create
        // duplicate Settings windows.
        try performMenuItem(named: "Settings…", in: menu)
        XCTAssertEqual(
            NSApp.windows.filter { $0.identifier == settingsIdentifier }.count,
            1
        )
        XCTAssertTrue(firstSettingsWindow.isVisible)

        try performMenuItem(named: "Enable Notch Surface", in: menu)
        XCTAssertEqual(coordinator.surfaceMode, .both)
        XCTAssertGreaterThanOrEqual(visibleNotchPanels.count, 2)

        let enabledMenu = try XCTUnwrap(coordinator.statusMenu)
        XCTAssertEqual(enabledMenu.item(withTitle: "Enable Notch Surface")?.state, .on)
        try performMenuItem(named: "Enable Notch Surface", in: enabledMenu)
        XCTAssertEqual(coordinator.surfaceMode, .menuBar)
        XCTAssertTrue(visibleNotchPanels.isEmpty)

        coordinator.stop()
        XCTAssertFalse(coordinator.isMenuBarItemInstalled)
        XCTAssertFalse(firstSettingsWindow.isVisible)
        XCTAssertTrue(NSApp.windows.filter { $0.title == "Garden Drop" && $0.isVisible }.isEmpty)
    }

    private var visibleNotchPanels: [NSWindow] {
        let notchLevel = NSWindow.Level.statusBar.rawValue + 1
        return NSApp.windows.filter {
            $0.isVisible
                && $0.level.rawValue == notchLevel
                && $0.styleMask.contains(.borderless)
        }
    }

    private func performMenuItem(named title: String, in menu: NSMenu) throws {
        let item = try XCTUnwrap(menu.item(withTitle: title))
        let action = try XCTUnwrap(item.action)
        XCTAssertTrue(NSApp.sendAction(action, to: item.target, from: item))
    }
}
