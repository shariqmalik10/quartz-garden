import AppKit
import Darwin
import Foundation

@MainActor
final class DiaryAppDelegate: NSObject, NSApplicationDelegate {
  static weak var appModel: DiaryAppModel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    if ProcessInfo.processInfo.environment["DIARY_SETTINGS_APP_SMOKE"] == "1" {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(250))
        guard let model = Self.appModel else {
          Self.write("PACKAGED_APP_SETTINGS_FAILED model unavailable\n", to: .standardError)
          exit(EXIT_FAILURE)
        }
        DiarySettingsWindowController.shared.show(model: model)
        try? await Task.sleep(for: .milliseconds(350))
        guard DiarySettingsWindowController.shared.isVisible else {
          Self.write("PACKAGED_APP_SETTINGS_FAILED window not visible\n", to: .standardError)
          exit(EXIT_FAILURE)
        }
        Self.write("PACKAGED_APP_SETTINGS_OK\n", to: .standardOutput)
        exit(EXIT_SUCCESS)
      }
      return
    }

    guard let audioPath = ProcessInfo.processInfo.environment["DIARY_COHERE_APP_SMOKE_AUDIO"],
      !audioPath.isEmpty
    else { return }

    Task.detached(priority: .userInitiated) {
      let clock = ContinuousClock()
      let start = clock.now
      do {
        let engine = CohereTranscriptionEngine()
        try await engine.prepareOffline()
        let text = try await engine.transcribe(
          audioURL: URL(fileURLWithPath: audioPath),
          language: "en"
        )
        let elapsed = start.duration(to: clock.now)
        Self.write(
          "PACKAGED_APP_COHERE_OK duration=\(elapsed) transcript=\(text)\n", to: .standardOutput)
        exit(EXIT_SUCCESS)
      } catch {
        Self.write("PACKAGED_APP_COHERE_FAILED \(error.localizedDescription)\n", to: .standardError)
        exit(EXIT_FAILURE)
      }
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let model = Self.appModel,
      model.capture.isRecording || model.workflowState.isBusy || model.isSaving
    else {
      return .terminateNow
    }

    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Finish the current diary entry first"
    alert.informativeText =
      "Diary Transcription is still recording, transcribing, or saving. Wait for it to finish so your audio stays recoverable."
    alert.addButton(withTitle: "Keep Running")
    alert.runModal()
    return .terminateCancel
  }

  private nonisolated static func write(_ message: String, to handle: FileHandle) {
    guard let data = message.data(using: .utf8) else { return }
    try? handle.write(contentsOf: data)
  }
}
