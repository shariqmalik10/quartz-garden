import AppKit
import SwiftUI

@MainActor
final class GardenDropCoordinator: NSObject, ObservableObject {
    private static let surfaceModeKey = "gardenDrop.surfaceMode"

    @Published private(set) var surfaceMode: CaptureSurfaceMode
    @Published private(set) var vaultConfiguration: VaultConfiguration
    let destinationStore: DestinationStore

    private let defaults: UserDefaults
    private let bookmarkStore: VaultBookmarkStore
    private var notchController: NotchPanelController?
    private var captureWindowController: CaptureWindowController?
    private var statusItem: NSStatusItem?
    private var hasStarted = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.bookmarkStore = VaultBookmarkStore(defaults: defaults)
        self.destinationStore = DestinationStore(defaults: defaults)
        self.vaultConfiguration = VaultConfiguration.runtime(
            bookmarkStore: VaultBookmarkStore(defaults: defaults)
        )
        let storedMode = defaults.string(forKey: Self.surfaceModeKey)
        let resolvedMode = CaptureSurfaceMode.migrated(from: storedMode)
        self.surfaceMode = resolvedMode
        super.init()

        destinationStore.refreshVisibility(for: vaultConfiguration.rootURL)

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

    @discardableResult
    func chooseVault() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Use Vault"
        panel.message = "Choose the root folder of your Obsidian vault."
        panel.directoryURL = vaultConfiguration.isFixture ? nil : vaultConfiguration.rootURL

        guard panel.runModal() == .OK,
              let url = panel.url,
              isDirectory(url) else {
            return false
        }

        do {
            try bookmarkStore.save(url: url)
            vaultConfiguration = VaultConfiguration(rootURL: url)
            destinationStore.refreshVisibility(for: url)
            updateCaptureSurfaces()
            return true
        } catch {
            return false
        }
    }

    func clearVault() {
        bookmarkStore.remove()
        vaultConfiguration = VaultConfiguration.runtime(bookmarkStore: bookmarkStore)
        destinationStore.refreshVisibility(for: vaultConfiguration.rootURL)
        updateCaptureSurfaces()
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
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
                destinationStore: destinationStore,
                vaultConfiguration: vaultConfiguration,
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
            captureWindowController = CaptureWindowController(
                destinationStore: destinationStore,
                vaultConfiguration: vaultConfiguration
            )
        }
        captureWindowController?.show()
    }

    private func updateCaptureSurfaces() {
        notchController?.updateVaultConfiguration(vaultConfiguration)
        captureWindowController?.updateVaultConfiguration(vaultConfiguration)
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
    @ObservedObject private var destinationStore: DestinationStore

    @State private var vaultSelectionMessage: String?

    init(coordinator: GardenDropCoordinator) {
        self.coordinator = coordinator
        self._destinationStore = ObservedObject(wrappedValue: coordinator.destinationStore)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var body: some View {
        Form {
            Section("Obsidian vault") {
                LabeledContent {
                    Text(
                        coordinator.vaultConfiguration.isConfigured
                            ? coordinator.vaultConfiguration.rootURL.path
                            : "No vault selected"
                    )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } label: {
                    Label(coordinator.vaultConfiguration.displayName, systemImage: "externaldrive")
                }

                HStack(spacing: 8) {
                    Button("Choose vault…") {
                        vaultSelectionMessage = coordinator.chooseVault()
                            ? "Vault access saved for future launches."
                            : "Vault selection was cancelled or could not be saved."
                    }

                    if coordinator.vaultConfiguration.isConfigured {
                        Button("Forget", role: .destructive) {
                            coordinator.clearVault()
                            vaultSelectionMessage = "No vault is selected. Choose a vault before saving captures."
                        }
                    }
                }

                if let vaultSelectionMessage {
                    Text(vaultSelectionMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Garden Drop stores only a security-scoped bookmark to this folder. Captures remain local Markdown files.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Quick destinations") {
                Text("Keep up to three folders one tap away in the notch and menu-bar composer. Blogs is included as a public-garden default.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(0..<3, id: \.self) { index in
                    quickDestinationRow(index: index)
                }
            }

            Section("Saved destinations") {
                HStack(spacing: 8) {
                    Button("Add folder…") {
                        chooseSavedDestination(.folder)
                    }
                    .disabled(!coordinator.vaultConfiguration.isConfigured)
                    Button("Add Markdown file…") {
                        chooseSavedDestination(.markdownFile)
                    }
                    .disabled(!coordinator.vaultConfiguration.isConfigured)
                }

                if destinationStore.savedDestinations.isEmpty {
                    Text("Choose a folder or Markdown file from a composer to keep it here for later.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(destinationStore.savedDestinations) { destination in
                        savedDestinationRow(destination)
                    }
                }
            }

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
        .frame(width: 520, height: 720)
    }

    @ViewBuilder
    private func quickDestinationRow(index: Int) -> some View {
        let destination = destinationStore.favorites.indices.contains(index)
            ? destinationStore.favorites[index]
            : nil

        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Image(systemName: destination?.kind.symbolName ?? "folder.badge.plus")
                .foregroundStyle(destination?.visibility == .garden ? gardenRust : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination?.title ?? "No folder selected")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(destination?.displayPath ?? "Choose a folder inside the vault")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Choose…") {
                chooseFavoriteFolder(at: index)
            }
            .accessibilityLabel("Choose quick destination \(index + 1)")
            .disabled(!coordinator.vaultConfiguration.isConfigured)
        }
    }

    private func savedDestinationRow(_ destination: CaptureDestination) -> some View {
        HStack(spacing: 10) {
            Image(systemName: destination.kind.symbolName)
                .foregroundStyle(destination.visibility == .garden ? gardenRust : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.title)
                    .font(.system(size: 12, weight: .medium))
                Text("\(destination.kind.displayName) · \(destination.displayPath)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if !destinationStore.favorites.contains(destination) {
                Button("Remove", role: .destructive) {
                    coordinator.destinationStore.forget(destination)
                }
                .accessibilityLabel("Remove \(destination.title) from saved destinations")
            }
        }
    }

    private func chooseFavoriteFolder(at index: Int) {
        guard coordinator.vaultConfiguration.isConfigured else {
            return
        }
        guard let destination = DestinationPicker.choose(
            kind: .folder,
            vaultRoot: coordinator.vaultConfiguration.rootURL
        ) else {
            return
        }
        coordinator.destinationStore.setFavorite(destination, at: index)
    }

    private func chooseSavedDestination(_ kind: CaptureDestinationKind) {
        guard coordinator.vaultConfiguration.isConfigured else {
            return
        }
        guard let destination = DestinationPicker.choose(
            kind: kind,
            vaultRoot: coordinator.vaultConfiguration.rootURL
        ) else {
            return
        }
        coordinator.destinationStore.remember(destination)
    }

    private var gardenRust: Color {
        Color(red: 0.741, green: 0.329, blue: 0.220)
    }
}
