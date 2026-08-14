import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let onComposerRequested: () -> Void
    private let onSettingsRequested: () -> Void

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
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 196,
                height: 32
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
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
        showIdle(animated: false)
    }

    func stop() {
        guard isStarted else {
            return
        }

        isStarted = false
        dwellWorkItem?.cancel()
        collapseWorkItem?.cancel()
        panel.orderOut(nil)
        isComposerVisible = false
    }

    func showComposer() {
        guard isStarted else {
            return
        }

        dwellWorkItem?.cancel()
        collapseWorkItem?.cancel()
        isComposerVisible = true
        setContent(
            AnyView(CaptureComposerView()),
            size: NotchMetrics.composerSize,
            onMouseEntered: {},
            onMouseExited: {},
            animationDuration: NotchMetrics.composerDuration
        )
        panel.makeKeyAndOrderFront(nil)
    }

    private func showIdle(animated: Bool) {
        guard isStarted else {
            return
        }

        guard let screen = activeScreen else {
            return
        }

        let size = NotchGeometry.idleSize(for: screen)
        isComposerVisible = false
        setContent(
            AnyView(NotchIdleView(size: size)),
            size: size,
            onMouseEntered: { [weak self] in
                self?.schedulePeek()
            },
            onMouseExited: { [weak self] in
                self?.cancelDwell()
            },
            animationDuration: animated ? NotchMetrics.collapseDuration : nil
        )
        panel.orderFrontRegardless()
    }

    private func showPeek() {
        guard isStarted, !isComposerVisible else {
            return
        }

        guard let screen = activeScreen else {
            return
        }

        let size = NotchGeometry.peekSize(for: screen)
        collapseWorkItem?.cancel()
        setContent(
            AnyView(
                NotchPeekView(size: size) { [weak self] in
                    self?.onComposerRequested()
                } onSettings: { [weak self] in
                    self?.onSettingsRequested()
                }
            ),
            size: size,
            onMouseEntered: { [weak self] in
                self?.collapseWorkItem?.cancel()
            },
            onMouseExited: { [weak self] in
                self?.scheduleCollapse()
            },
            animationDuration: NotchMetrics.expandDuration
        )
        panel.orderFrontRegardless()
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
        DispatchQueue.main.asyncAfter(
            deadline: .now() + NotchMetrics.hoverDelay,
            execute: workItem
        )
    }

    private func cancelDwell() {
        dwellWorkItem?.cancel()
        dwellWorkItem = nil
    }

    private func scheduleCollapse() {
        cancelDwell()
        guard !isComposerVisible else {
            return
        }

        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.collapseIfPointerOutside()
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + NotchMetrics.collapseDelay,
            execute: workItem
        )
    }

    private func collapseIfPointerOutside() {
        guard isStarted, !isComposerVisible else {
            return
        }

        guard !panel.frame.contains(NSEvent.mouseLocation) else {
            return
        }

        showIdle(animated: true)
    }

    private func setContent(
        _ content: AnyView,
        size: NSSize,
        onMouseEntered: @escaping () -> Void,
        onMouseExited: @escaping () -> Void,
        animationDuration: TimeInterval?
    ) {
        let hostingView = HoverHostingView(rootView: content)
        hostingView.onMouseEntered = onMouseEntered
        hostingView.onMouseExited = onMouseExited
        panel.contentView = hostingView

        guard let screen = activeScreen else {
            return
        }

        let frame = NotchGeometry.frame(for: size, on: screen)

        if let animationDuration {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private var activeScreen: NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }
}

private enum NotchMetrics {
    static let composerSize = NSSize(width: 420, height: 440)
    static let hoverDelay: TimeInterval = 0.12
    static let collapseDelay: TimeInterval = 0.12
    static let expandDuration: TimeInterval = 0.15
    static let collapseDuration: TimeInterval = 0.22
    static let composerDuration: TimeInterval = 0.24
}

private enum NotchGeometry {
    static func notchRect(for screen: NSScreen) -> NSRect? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return nil
        }

        return NSRect(
            x: left.maxX,
            y: left.minY,
            width: right.minX - left.maxX,
            height: max(left.height, right.height)
        )
    }

    static func idleSize(for screen: NSScreen) -> NSSize {
        guard let notchRect = notchRect(for: screen) else {
            return NSSize(width: 196, height: 32)
        }

        return NSSize(
            width: notchRect.width + 11,
            height: notchRect.height
        )
    }

    static func peekSize(for screen: NSScreen) -> NSSize {
        guard let notchRect = notchRect(for: screen) else {
            return NSSize(width: 224, height: 48)
        }

        return NSSize(
            width: notchRect.width + 39,
            height: notchRect.height + 16
        )
    }

    static func frame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let safeTop = max(0, screen.safeAreaInsets.top)
        let visibleTop = screenFrame.maxY - safeTop

        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: visibleTop - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private final class HoverHostingView: NSHostingView<AnyView> {
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
