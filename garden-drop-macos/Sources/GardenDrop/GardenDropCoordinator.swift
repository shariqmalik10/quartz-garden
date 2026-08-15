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
        let resolvedMode = CaptureSurfaceMode.migrated(from: storedMode)
        self.surfaceMode = resolvedMode
        super.init()

        if storedMode != resolvedMode.rawValue {
            defaults.set(resolvedMode.rawValue, forKey: Self.surfaceModeKey)
        }
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        updateMenuBarItem()
        applySurfaceMode()
    }

    func stop() {
        guard hasStarted else {
            return
        }

        notchController?.stop()
        captureWindowController?.close()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        hasStarted = false
    }

    var isMenuBarItemInstalled: Bool {
        statusItem != nil
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

    func setNotchEnabled(_ isEnabled: Bool) {
        setSurfaceMode(isEnabled ? .both : .menuBar)
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

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let image = NSImage(
                systemSymbolName: "tray.and.arrow.down",
                accessibilityDescription: "Garden Drop"
            ) {
                image.isTemplate = true
                item.button?.image = image
                item.button?.imagePosition = .imageOnly
            } else {
                item.length = NSStatusItem.variableLength
                item.button?.title = "Drop"
            }
            item.button?.toolTip = "Garden Drop"
            item.isVisible = true
            statusItem = item
        }

        statusItem?.menu = makeStatusMenu()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu(title: "Garden Drop")

        let captureItem = NSMenuItem(
            title: "New Capture…",
            action: #selector(menuCaptureNow),
            keyEquivalent: "n"
        )
        captureItem.target = self
        captureItem.keyEquivalentModifierMask = [.command]
        menu.addItem(captureItem)

        let notchItem = NSMenuItem(
            title: "Enable Notch Surface",
            action: #selector(menuToggleNotch),
            keyEquivalent: ""
        )
        notchItem.target = self
        notchItem.state = surfaceMode.showsNotch ? .on : .off
        menu.addItem(notchItem)

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

    @objc private func menuToggleNotch() {
        setNotchEnabled(!surfaceMode.showsNotch)
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
        NSApp.setActivationPolicy(.accessory)
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }
}

struct GardenDropSettingsView: View {
    @ObservedObject var coordinator: GardenDropCoordinator

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var body: some View {
        Form {
            Section("Menu bar") {
                LabeledContent {
                    Text("Always on")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Garden Drop", systemImage: "tray.and.arrow.down")
                }

                Text("Use the menu-bar icon to start a new capture, open settings, or quit the app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Notch shortcut") {
                Toggle(
                    "Enable notch surface",
                    isOn: Binding(
                        get: { coordinator.surfaceMode.showsNotch },
                        set: { coordinator.setNotchEnabled($0) }
                    )
                )

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
        .frame(width: 430, height: 310)
    }
}
