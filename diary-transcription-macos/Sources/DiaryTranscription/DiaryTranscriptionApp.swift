import SwiftUI

@main
struct DiaryTranscriptionApp: App {
    @State private var model = DiaryAppModel()

    var body: some Scene {
        MenuBarExtra("Diary Transcription", systemImage: "book.pages") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            DiarySettingsView(model: model)
                .task { await model.restoreVault() }
        }
    }
}
