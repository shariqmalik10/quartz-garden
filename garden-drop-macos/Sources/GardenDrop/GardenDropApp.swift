import SwiftUI

@main
struct GardenDropApp: App {
    var body: some Scene {
        WindowGroup("Garden Drop") {
            CaptureComposerView()
        }
        .defaultSize(width: 420, height: 380)
        .windowResizability(.contentSize)
    }
}
