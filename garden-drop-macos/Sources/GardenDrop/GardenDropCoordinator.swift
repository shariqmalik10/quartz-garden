import AppKit
import SwiftUI

@MainActor
final class GardenDropCoordinator: NSObject, ObservableObject {
    private static let surfaceModeKey = "gardenDrop.surfaceMode"

    @Published private(set) var surfaceMode: CaptureSurfaceMode

    private let defaults: UserDefaults
    private var notchController: NotchPanelController?
    private var captureWindowController: CaptureWindowController?
    private var statusItem: NSStatusItem?
    private var hasStarted = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedMode = defaults.string(forKey: Self.surfaceModeKey)
            .flatMap(CaptureSurfaceMode.init(rawValue:))
            ?? .both
        self.surfaceMode = storedMode
        super.init()
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        applySurfaceMode()
        updateMenuBarItem()
    }

    func setSurfaceMode(_ mode: CaptureSurfaceMode) {
        guard mode != surfaceMode else {
            return
        }

        surfaceMode = mode
        defaults.set(mode.rawValue, forKey: Self.surfaceModeKey)
        applySurfaceMode()
        updateMenuBarItem()
    }

    func openMenuBarCapture() {
        showMenuBarComposer()
    }

    func openSettings() {
        NSApp.sendAction(
            Selector(("showSettingsWindow:")),
            to: nil,
            from: nil
        )
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func applySurfaceMode() {
        if notchController == nil {
            notchController = NotchPanelController(
                onComposerRequested: { [weak self] in
                    self?.showNotchComposer()
                },
                onSettingsRequested: { [weak self] in
                    self?.openSettings()
                }
            )
        }

        if surfaceMode.showsNotch {
            notchController?.start()
        } else {
            notchController?.stop()
        }
    }

    private func showNotchComposer() {
        notchController?.showComposer()
    }

    private func showMenuBarComposer() {
        if captureWindowController == nil {
            captureWindowController = CaptureWindowController()
        }
        captureWindowController?.show()
    }

    private func updateMenuBarItem() {
        guard hasStarted else {
            return
        }

        if surfaceMode.showsMenuBar {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                item.button?.image = NSImage(
                    systemSymbolName: "tray.and.arrow.down",
                    accessibilityDescription: "Garden Drop"
                )
                item.button?.imagePosition = .imageOnly
                item.button?.toolTip = "Garden Drop"
                statusItem = item
            }
            statusItem?.menu = makeStatusMenu()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu(title: "Garden Drop")

        let captureItem = NSMenuItem(
            title: "Capture Now",
            action: #selector(menuCaptureNow),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        let surfaceItem = NSMenuItem(title: "Capture Surface", action: nil, keyEquivalent: "")
        let surfaceMenu = NSMenu(title: "Capture Surface")
        for mode in CaptureSurfaceMode.allCases {
            let modeItem = NSMenuItem(
                title: mode.title,
                action: #selector(menuSelectSurface(_:)),
                keyEquivalent: ""
            )
            modeItem.target = self
            modeItem.representedObject = mode.rawValue
            modeItem.state = mode == surfaceMode ? .on : .off
            surfaceMenu.addItem(modeItem)
        }
        surfaceItem.submenu = surfaceMenu
        menu.addItem(surfaceItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(menuOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit Garden Drop",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func menuCaptureNow() {
        openMenuBarCapture()
    }

    @objc private func menuSelectSurface(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = CaptureSurfaceMode(rawValue: rawValue) else {
            return
        }
        setSurfaceMode(mode)
    }

    @objc private func menuOpenSettings() {
        openSettings()
    }

    @objc private func menuQuit() {
        quit()
    }
}

@MainActor
final class GardenDropAppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = GardenDropCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }
}

struct GardenDropSettingsView: View {
    @ObservedObject var coordinator: GardenDropCoordinator

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var body: some View {
        Form {
            Section("Capture surface") {
                Picker(
                    "Show Garden Drop in",
                    selection: Binding(
                        get: { coordinator.surfaceMode },
                        set: { coordinator.setSurfaceMode($0) }
                    )
                ) {
                    ForEach(CaptureSurfaceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(coordinator.surfaceMode.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Current build") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Capture", value: "Local Markdown")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 260)
    }
}
