import SwiftUI

@main
struct GardenDropApp: App {
    @NSApplicationDelegateAdaptor(GardenDropAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            GardenDropSettingsView(coordinator: appDelegate.coordinator)
        }
    }
}
