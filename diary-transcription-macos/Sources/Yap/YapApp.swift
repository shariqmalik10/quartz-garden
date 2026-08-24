import SwiftUI

@main
struct YapApp: App {
    @NSApplicationDelegateAdaptor(DiaryAppDelegate.self) private var appDelegate
    @State private var model = DiaryAppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Label(
                model.capture.isRecording ? "Yap is recording" : "Yap",
                systemImage: model.capture.isRecording ? "waveform" : "book.pages"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            DiarySettingsView(model: model)
                .task { await model.restoreVault() }
        }
    }
}
