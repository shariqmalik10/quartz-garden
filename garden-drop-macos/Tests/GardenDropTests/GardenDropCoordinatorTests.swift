import AppKit
import XCTest
@testable import GardenDrop

@MainActor
final class GardenDropCoordinatorTests: XCTestCase {
    func testMenuBarLifecycleAndActionsRemainAvailableAcrossNotchToggles() throws {
        let harness = makeHarness()
        defer { harness.cleanUp() }

        harness.coordinator.start()
        let initialMenu = try XCTUnwrap(harness.coordinator.statusMenu)

        XCTAssertTrue(harness.coordinator.isMenuBarItemInstalled)
        XCTAssertEqual(
            initialMenu.items.filter { !$0.isSeparatorItem }.map(\.title),
            ["New Capture…", "Enable Notch Surface", "Settings…", "Quit Garden Drop"]
        )

        performMenuItem(named: "New Capture…", in: initialMenu)
        XCTAssertEqual(harness.capture.showCallCount, 1)
        XCTAssertEqual(harness.captureFactoryCallCount.value, 1)

        performMenuItem(named: "Enable Notch Surface", in: initialMenu)
        XCTAssertEqual(harness.coordinator.surfaceMode, .both)
        XCTAssertTrue(harness.coordinator.isMenuBarItemInstalled)
        XCTAssertEqual(harness.notch.startCallCount, 1)

        let enabledMenu = try XCTUnwrap(harness.coordinator.statusMenu)
        XCTAssertEqual(enabledMenu.item(withTitle: "Enable Notch Surface")?.state, .on)
        performMenuItem(named: "Enable Notch Surface", in: enabledMenu)

        XCTAssertEqual(harness.coordinator.surfaceMode, .menuBar)
        XCTAssertTrue(harness.coordinator.isMenuBarItemInstalled)
        XCTAssertGreaterThanOrEqual(harness.notch.stopCallCount, 1)
        XCTAssertEqual(
            harness.coordinator.statusMenu?.item(withTitle: "Enable Notch Surface")?.state,
            .off
        )
    }

    func testSettingsMenuAndNotchCallbackUseTheSameRetainedPresenterRepeatedly() throws {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        harness.coordinator.start()

        let menu = try XCTUnwrap(harness.coordinator.statusMenu)
        performMenuItem(named: "Settings…", in: menu)
        performMenuItem(named: "Settings…", in: menu)

        XCTAssertEqual(harness.settingsFactoryCallCount.value, 1)
        XCTAssertEqual(harness.settings.showCallCount, 2)

        harness.notch.requestSettings()
        harness.notch.requestSettings()

        XCTAssertEqual(harness.settingsFactoryCallCount.value, 1)
        XCTAssertEqual(harness.settings.showCallCount, 4)
    }

    func testStartIsIdempotentAndStopClosesWindowsAndRemovesStatusItem() throws {
        let harness = makeHarness()
        defer { harness.cleanUp() }

        harness.coordinator.start()
        let initialMenu = try XCTUnwrap(harness.coordinator.statusMenu)
        harness.coordinator.start()

        XCTAssertTrue(initialMenu === harness.coordinator.statusMenu)

        performMenuItem(named: "New Capture…", in: initialMenu)
        performMenuItem(named: "Settings…", in: initialMenu)
        harness.coordinator.stop()

        XCTAssertFalse(harness.coordinator.isMenuBarItemInstalled)
        XCTAssertNil(harness.coordinator.statusMenu)
        XCTAssertEqual(harness.capture.closeCallCount, 1)
        XCTAssertEqual(harness.settings.closeCallCount, 1)
        XCTAssertGreaterThanOrEqual(harness.notch.stopCallCount, 1)

        harness.coordinator.stop()
        XCTAssertEqual(harness.capture.closeCallCount, 1)
        XCTAssertEqual(harness.settings.closeCallCount, 1)
    }

    func testQuitMenuUsesInjectedTerminationPlumbing() throws {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        harness.coordinator.start()

        performMenuItem(
            named: "Quit Garden Drop",
            in: try XCTUnwrap(harness.coordinator.statusMenu)
        )

        XCTAssertEqual(harness.terminationCallCount.value, 1)
        XCTAssertTrue(harness.coordinator.isMenuBarItemInstalled)
    }

    func testMenuItemKeyboardEquivalentsAreStable() throws {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        harness.coordinator.start()
        let menu = try XCTUnwrap(harness.coordinator.statusMenu)

        let capture = try XCTUnwrap(menu.item(withTitle: "New Capture…"))
        XCTAssertEqual(capture.keyEquivalent, "n")
        XCTAssertEqual(capture.keyEquivalentModifierMask, [.command])

        let settings = try XCTUnwrap(menu.item(withTitle: "Settings…"))
        XCTAssertEqual(settings.keyEquivalent, ",")

        let quit = try XCTUnwrap(menu.item(withTitle: "Quit Garden Drop"))
        XCTAssertEqual(quit.keyEquivalent, "q")
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

    private func performMenuItem(named title: String, in menu: NSMenu) {
        guard let item = menu.item(withTitle: title),
              let action = item.action else {
            XCTFail("Missing actionable menu item named \(title)")
            return
        }

        XCTAssertTrue(NSApp.sendAction(action, to: item.target, from: item))
    }

    private func makeHarness() -> CoordinatorHarness {
        let suiteName = "GardenDropCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = SettingsPresenterSpy()
        let capture = CaptureWindowSpy()
        let notch = NotchControllerSpy()
        let settingsFactoryCallCount = CoordinatorCallCounter()
        let captureFactoryCallCount = CoordinatorCallCounter()
        let terminationCallCount = CoordinatorCallCounter()

        let coordinator = GardenDropCoordinator(
            defaults: defaults,
            settingsPresenterFactory: { _ in
                settingsFactoryCallCount.value += 1
                return settings
            },
            captureWindowFactory: { _, _ in
                captureFactoryCallCount.value += 1
                return capture
            },
            notchControllerFactory: { _, _, onComposer, onSettings in
                notch.onComposerRequested = onComposer
                notch.onSettingsRequested = onSettings
                return notch
            },
            terminateApplication: {
                terminationCallCount.value += 1
            }
        )

        return CoordinatorHarness(
            coordinator: coordinator,
            defaults: defaults,
            suiteName: suiteName,
            settings: settings,
            capture: capture,
            notch: notch,
            settingsFactoryCallCount: settingsFactoryCallCount,
            captureFactoryCallCount: captureFactoryCallCount,
            terminationCallCount: terminationCallCount
        )
    }
}

@MainActor
private struct CoordinatorHarness {
    let coordinator: GardenDropCoordinator
    let defaults: UserDefaults
    let suiteName: String
    let settings: SettingsPresenterSpy
    let capture: CaptureWindowSpy
    let notch: NotchControllerSpy
    let settingsFactoryCallCount: CoordinatorCallCounter
    let captureFactoryCallCount: CoordinatorCallCounter
    let terminationCallCount: CoordinatorCallCounter

    func cleanUp() {
        coordinator.stop()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class CoordinatorCallCounter {
    var value = 0
}

@MainActor
private final class SettingsPresenterSpy: GardenDropSettingsPresenting {
    private(set) var showCallCount = 0
    private(set) var closeCallCount = 0

    func show() {
        showCallCount += 1
    }

    func close() {
        closeCallCount += 1
    }
}

@MainActor
private final class CaptureWindowSpy: GardenDropCaptureWindowPresenting {
    private(set) var showCallCount = 0
    private(set) var closeCallCount = 0
    private(set) var configurations: [VaultConfiguration] = []

    func show() {
        showCallCount += 1
    }

    func close() {
        closeCallCount += 1
    }

    func updateVaultConfiguration(_ configuration: VaultConfiguration) {
        configurations.append(configuration)
    }
}

@MainActor
private final class NotchControllerSpy: GardenDropNotchControlling {
    var onComposerRequested: (() -> Void)?
    var onSettingsRequested: (() -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var composerSources: [CaptureSource] = []
    private(set) var configurations: [VaultConfiguration] = []

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func showComposer(source: CaptureSource) {
        composerSources.append(source)
    }

    func updateVaultConfiguration(_ configuration: VaultConfiguration) {
        configurations.append(configuration)
    }

    func requestSettings() {
        onSettingsRequested?()
    }
}
