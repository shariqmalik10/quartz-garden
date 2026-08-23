import AppKit
import SwiftUI

@MainActor
final class DiarySettingsWindowController: NSObject, NSWindowDelegate {
  static let shared = DiarySettingsWindowController()

  private var windowController: NSWindowController?

  var isVisible: Bool {
    windowController?.window?.isVisible == true
  }

  func show(model: DiaryAppModel) {
    if let window = windowController?.window {
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      return
    }

    let hostingController = NSHostingController(
      rootView: DiarySettingsView(model: model)
    )
    let window = NSWindow(contentViewController: hostingController)
    window.title = "Diary Transcription Settings"
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.setContentSize(NSSize(width: 680, height: 610))
    window.minSize = NSSize(width: 640, height: 560)
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()

    let controller = NSWindowController(window: window)
    windowController = controller
    NSApp.activate(ignoringOtherApps: true)
    controller.showWindow(nil)
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    windowController = nil
  }
}
