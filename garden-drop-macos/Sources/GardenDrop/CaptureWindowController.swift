import AppKit
import SwiftUI

@MainActor
final class CaptureWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Garden Drop"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: CaptureComposerView(model: CaptureComposerModel(source: .blank))
        )
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
