import SwiftUI

@main
struct GardenDropApp: App {
    @StateObject private var coordinator = GardenDropCoordinator()

    var body: some Scene {
        MenuBarExtra(
            "Garden Drop",
            systemImage: "tray.and.arrow.down",
            isInserted: $coordinator.isMenuBarVisible
        ) {
            MenuBarView(coordinator: coordinator)
        }

        Settings {
            GardenDropSettingsView(coordinator: coordinator)
        }
    }
}
