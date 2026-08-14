import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let onComposerRequested: () -> Void
    private let onSettingsRequested: () -> Void

    private var trackingWindow: NSWindow?
    private var dwellWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var isComposerVisible = false
    private var isStarted = false

    init(
        onComposerRequested: @escaping () -> Void,
        onSettingsRequested: @escaping () -> Void
    ) {
        self.onComposerRequested = onComposerRequested
        self.onSettingsRequested = onSettingsRequested
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 76),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
    }

    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        installTrackingWindow()
    }

    func stop() {
        guard isStarted else {
            return
        }

        isStarted = false
        dwellWorkItem?.cancel()
        collapseWorkItem?.cancel()
        trackingWindow?.orderOut(nil)
        trackingWindow = nil
        panel.orderOut(nil)
        isComposerVisible = false
    }

    func showComposer() {
        guard isStarted else {
            return
        }

        collapseWorkItem?.cancel()
        isComposerVisible = true
        setContent(AnyView(CaptureComposerView()), size: NSSize(width: 420, height: 380))
        panel.makeKeyAndOrderFront(nil)
    }

    private func installTrackingWindow() {
        guard let screen = activeScreen else {
            return
        }

        let trackingRect = NotchGeometry.trackingRect(for: screen)
        let window = NSWindow(
            contentRect: trackingRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.alphaValue = 0.01
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = NotchTrackingView(frame: NSRect(origin: .zero, size: trackingRect.size))
        view.onMouseEntered = { [weak self] in
            self?.schedulePeek()
        }
        view.onMouseExited = { [weak self] in
            self?.scheduleCollapse()
        }
        window.contentView = view
        window.orderFrontRegardless()
        trackingWindow = window
    }

    private func schedulePeek() {
        guard !isComposerVisible else {
            return
        }

        dwellWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.showPeek()
        }
        dwellWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func scheduleCollapse() {
        dwellWorkItem?.cancel()
        guard !isComposerVisible else {
            return
        }

        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func showPeek() {
        guard isStarted, !isComposerVisible else {
            return
        }

        collapseWorkItem?.cancel()
        setContent(
            AnyView(
                NotchPeekView { [weak self] in
                    self?.onComposerRequested()
                } onSettings: { [weak self] in
                    self?.onSettingsRequested()
                }
            ),
            size: NSSize(width: 340, height: 76)
        )
        panel.orderFrontRegardless()
    }

    private func setContent(_ content: AnyView, size: NSSize) {
        panel.contentView = NSHostingView(rootView: content)
        guard let screen = activeScreen else {
            return
        }

        let screenFrame = screen.frame
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height
        )
        panel.setFrame(
            NSRect(origin: origin, size: size),
            display: true,
            animate: true
        )
    }

    private var activeScreen: NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }
}

private enum NotchGeometry {
    static func trackingRect(for screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top
        let height = max(22, min(topInset, 44))
        let width = topInset > 0
            ? min(260, max(190, frame.width * 0.16))
            : 160

        return NSRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }
}

private final class NotchTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
