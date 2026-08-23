import XCTest
@testable import GardenDrop

@MainActor
final class GardenDropSettingsPresenterTests: XCTestCase {
    func testShowCreatesOneWindowAndActivatesShowsAndFocusesEveryTime() {
        let suiteName = "GardenDropSettingsPresenterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let coordinator = GardenDropCoordinator(defaults: defaults)
        let events = SettingsEventLog()
        let window = SettingsWindowSpy(events: events)
        let factoryCallCount = SettingsCallCounter()
        let presenter = GardenDropSettingsWindowPresenter(
            coordinator: coordinator,
            makeWindow: { receivedCoordinator in
                XCTAssertTrue(receivedCoordinator === coordinator)
                factoryCallCount.value += 1
                return window
            },
            activateApplication: {
                events.values.append("activate")
            }
        )

        presenter.show()
        XCTAssertEqual(factoryCallCount.value, 1)
        XCTAssertEqual(events.values, ["center", "activate", "show", "focus"])

        events.values.removeAll()
        presenter.show()
        XCTAssertEqual(factoryCallCount.value, 1)
        XCTAssertEqual(events.values, ["activate", "show", "focus"])
    }

    func testShowRecentersAClosedWindowAndCloseIsForwarded() {
        let suiteName = "GardenDropSettingsPresenterCloseTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let coordinator = GardenDropCoordinator(defaults: defaults)
        let events = SettingsEventLog()
        let window = SettingsWindowSpy(events: events)
        let presenter = GardenDropSettingsWindowPresenter(
            coordinator: coordinator,
            makeWindow: { _ in window },
            activateApplication: { events.values.append("activate") }
        )

        presenter.show()
        presenter.close()
        XCTAssertEqual(events.values.last, "close")

        events.values.removeAll()
        presenter.show()
        XCTAssertEqual(events.values, ["center", "activate", "show", "focus"])
    }
}

@MainActor
private final class SettingsEventLog {
    var values: [String] = []
}

@MainActor
private final class SettingsCallCounter {
    var value = 0
}

@MainActor
private final class SettingsWindowSpy: GardenDropSettingsWindowPresenting {
    private let events: SettingsEventLog
    private(set) var isVisible = false

    init(events: SettingsEventLog) {
        self.events = events
    }

    func center() {
        events.values.append("center")
    }

    func show() {
        events.values.append("show")
        isVisible = true
    }

    func makeKeyAndOrderFront() {
        events.values.append("focus")
    }

    func close() {
        events.values.append("close")
        isVisible = false
    }
}
