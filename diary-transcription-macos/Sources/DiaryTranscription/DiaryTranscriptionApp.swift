import SwiftUI

@main
struct DiaryTranscriptionApp: App {
    @State private var model = DiaryAppModel()
    @State private var capture = AudioCaptureModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model, capture: capture)
        } label: {
            Label(
                capture.isRecording ? "Diary Transcription is recording" : "Diary Transcription",
                systemImage: capture.isRecording ? "waveform" : "book.pages"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            DiarySettingsView(model: model)
                .task { await model.restoreVault() }
        }
    }
}
