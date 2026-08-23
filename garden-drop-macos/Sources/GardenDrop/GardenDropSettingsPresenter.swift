import AppKit
import SwiftUI

@MainActor
protocol GardenDropSettingsPresenting: AnyObject {
    func show()
    func close()
}

@MainActor
protocol GardenDropSettingsWindowPresenting: AnyObject {
    var isVisible: Bool { get }

    func center()
    func show()
    func makeKeyAndOrderFront()
    func close()
}

@MainActor
final class GardenDropSettingsWindowPresenter: GardenDropSettingsPresenting {
    typealias WindowFactory = @MainActor (GardenDropCoordinator) -> any GardenDropSettingsWindowPresenting

    private unowned let coordinator: GardenDropCoordinator
    private let makeWindow: WindowFactory
    private let activateApplication: @MainActor () -> Void
    private var settingsWindow: (any GardenDropSettingsWindowPresenting)?

    init(
        coordinator: GardenDropCoordinator,
        makeWindow: @escaping WindowFactory = { GardenDropSettingsWindow(coordinator: $0) },
        activateApplication: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        self.coordinator = coordinator
        self.makeWindow = makeWindow
        self.activateApplication = activateApplication
    }

    func show() {
        let window = settingsWindow ?? makeSettingsWindow()

        if !window.isVisible {
            window.center()
        }

        // Accessory apps do not become active just because a window is ordered in.
        // Activate explicitly, then make the retained settings window key so repeated
        // requests also bring an already-open window back to the front.
        activateApplication()
        window.show()
        window.makeKeyAndOrderFront()
    }

    func close() {
        settingsWindow?.close()
    }

    private func makeSettingsWindow() -> any GardenDropSettingsWindowPresenting {
        let window = makeWindow(coordinator)
        settingsWindow = window
        return window
    }
}

@MainActor
private final class GardenDropSettingsWindow: NSWindowController, GardenDropSettingsWindowPresenting {
    init(coordinator: GardenDropCoordinator) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Garden Drop Settings"
        window.identifier = NSUserInterfaceItemIdentifier("GardenDrop.Settings")
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(
            rootView: GardenDropSettingsView(coordinator: coordinator)
        )
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func center() {
        window?.center()
    }

    func show() {
        showWindow(nil)
    }

    func makeKeyAndOrderFront() {
        window?.makeKeyAndOrderFront(nil)
    }
}
