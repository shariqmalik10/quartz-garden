import AppKit
import SwiftUI

@MainActor
final class GardenDropCoordinator: ObservableObject {
    private static let surfaceModeKey = "gardenDrop.surfaceMode"

    @Published private(set) var surfaceMode: CaptureSurfaceMode
    @Published var isMenuBarVisible: Bool

    private let defaults: UserDefaults
    private var notchController: NotchPanelController?
    private var captureWindowController: CaptureWindowController?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedMode = defaults.string(forKey: Self.surfaceModeKey)
            .flatMap(CaptureSurfaceMode.init(rawValue:))
            ?? .both
        self.surfaceMode = storedMode
        self.isMenuBarVisible = storedMode.showsMenuBar

        Task { @MainActor [weak self] in
            self?.applySurfaceMode()
        }
    }

    func setSurfaceMode(_ mode: CaptureSurfaceMode) {
        guard mode != surfaceMode else {
            return
        }

        surfaceMode = mode
        isMenuBarVisible = mode.showsMenuBar
        defaults.set(mode.rawValue, forKey: Self.surfaceModeKey)
        applySurfaceMode()
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
}

struct MenuBarView: View {
    @ObservedObject var coordinator: GardenDropCoordinator

    var body: some View {
        Button {
            coordinator.openMenuBarCapture()
        } label: {
            Label("Capture Now", systemImage: "tray.and.arrow.down")
        }

        Menu {
            ForEach(CaptureSurfaceMode.allCases) { mode in
                Button {
                    coordinator.setSurfaceMode(mode)
                } label: {
                    Label(
                        mode.title,
                        systemImage: mode == coordinator.surfaceMode ? "checkmark" : mode.symbolName
                    )
                }
            }
        } label: {
            Label("Capture Surface", systemImage: coordinator.surfaceMode.symbolName)
        }

        Divider()

        Button {
            coordinator.openSettings()
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }

        Button {
            coordinator.quit()
        } label: {
            Label("Quit Garden Drop", systemImage: "power")
        }
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
