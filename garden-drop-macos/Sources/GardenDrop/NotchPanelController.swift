import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: KeyableNotchPanel
    private let presentation = NotchSurfacePresentation()
    private let onComposerRequested: () -> Void
    private let onSettingsRequested: () -> Void

    private var hostingView: HoverHostingView?
    private var dwellWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var isStarted = false

    init(
        onComposerRequested: @escaping () -> Void,
        onSettingsRequested: @escaping () -> Void
    ) {
        self.onComposerRequested = onComposerRequested
        self.onSettingsRequested = onSettingsRequested
        self.panel = KeyableNotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 196, height: 32),
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
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none
    }

    func start() {
        guard !isStarted, let screen = activeScreen else {
            return
        }

        isStarted = true
        installSurfaceIfNeeded()
        presentation.safeTopInset = screen.safeAreaInsets.top
        presentation.showIdle()
        panel.setFrame(NotchGeometry.frame(for: NotchGeometry.idleSize(for: screen), on: screen), display: true)
        panel.orderFrontRegardless()
    }

    func stop() {
        guard isStarted else {
            return
        }

        isStarted = false
        cancelScheduledTransitions()
        panel.orderOut(nil)
        presentation.showIdle()
    }

    func showComposer() {
        guard isStarted, let screen = activeScreen else {
            return
        }

        cancelScheduledTransitions()
        presentation.safeTopInset = screen.safeAreaInsets.top
        presentation.showComposer(CaptureComposerModel(source: .blank))

        focusComposerPanel()
        transitionPanel(
            to: NotchComposerLayout.size,
            on: screen,
            duration: NotchMetrics.composerDuration
        )

        DispatchQueue.main.async { [weak self] in
            self?.focusComposerPanel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard self?.presentation.phase == .composer else {
                return
            }
            self?.focusComposerPanel()
        }
    }

    private func installSurfaceIfNeeded() {
        guard hostingView == nil else {
            return
        }

        let rootView = NotchSurfaceRootView(
            presentation: presentation,
            onOpen: { [weak self] in
                self?.onComposerRequested()
            },
            onSettings: { [weak self] in
                self?.onSettingsRequested()
            },
            onClose: { [weak self] in
                self?.showIdle(animated: true)
            }
        )
        let hostingView = HoverHostingView(rootView: AnyView(rootView))
        hostingView.onMouseEntered = { [weak self] in
            self?.pointerEntered()
        }
        hostingView.onMouseExited = { [weak self] in
            self?.pointerExited()
        }
        panel.contentView = hostingView
        self.hostingView = hostingView
    }

    private func pointerEntered() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        guard presentation.phase == .idle else {
            return
        }
        schedulePeek()
    }

    private func pointerExited() {
        switch presentation.phase {
        case .idle:
            cancelDwell()
        case .peek:
            scheduleCollapse()
        case .composer:
            break
        }
    }

    private func showIdle(animated: Bool) {
        guard isStarted, let screen = activeScreen else {
            return
        }

        let previousPhase = presentation.phase
        cancelScheduledTransitions()
        presentation.safeTopInset = screen.safeAreaInsets.top
        presentation.showIdle()

        let duration = previousPhase == .composer
            ? NotchMetrics.composerCloseDuration
            : NotchMetrics.collapseDuration
        transitionPanel(
            to: NotchGeometry.idleSize(for: screen),
            on: screen,
            duration: animated ? duration : nil
        )
        panel.orderFrontRegardless()
        panel.resignKey()
    }

    private func showPeek() {
        guard isStarted,
              presentation.phase == .idle,
              let screen = activeScreen else {
            return
        }

        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        presentation.safeTopInset = screen.safeAreaInsets.top
        presentation.showPeek()
        transitionPanel(
            to: NotchGeometry.peekSize(for: screen),
            on: screen,
            duration: NotchMetrics.expandDuration
        )
        panel.orderFrontRegardless()
    }

    private func schedulePeek() {
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
        guard presentation.phase == .peek else {
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
        guard isStarted, presentation.phase == .peek else {
            return
        }

        guard !panel.frame.contains(NSEvent.mouseLocation) else {
            return
        }
        showIdle(animated: true)
    }

    private func cancelScheduledTransitions() {
        dwellWorkItem?.cancel()
        collapseWorkItem?.cancel()
        dwellWorkItem = nil
        collapseWorkItem = nil
    }

    private func transitionPanel(
        to size: NSSize,
        on screen: NSScreen,
        duration: TimeInterval?
    ) {
        let frame = NotchGeometry.frame(for: size, on: screen)
        let shouldReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard let duration, !shouldReduceMotion else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = NotchMetrics.easeOut
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func focusComposerPanel() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    private var activeScreen: NSScreen? {
        NSScreen.screens.first(where: {
            $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
        })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private enum NotchMetrics {
    static let hoverDelay: TimeInterval = 0.10
    static let collapseDelay: TimeInterval = 0.10
    static let expandDuration: TimeInterval = 0.22
    static let collapseDuration: TimeInterval = 0.18
    static let composerDuration: TimeInterval = 0.32
    static let composerCloseDuration: TimeInterval = 0.22
    @MainActor
    static var easeOut: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.30, 1.0)
    }
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

        return NSSize(width: notchRect.width + 11, height: notchRect.height)
    }

    static func peekSize(for screen: NSScreen) -> NSSize {
        guard let notchRect = notchRect(for: screen) else {
            return NSSize(width: 224, height: 48)
        }

        return NSSize(width: notchRect.width + 39, height: notchRect.height + 16)
    }

    static func frame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private final class KeyableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window?.makeKey()
        super.mouseDown(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
