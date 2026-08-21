import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: KeyableNotchPanel
    private let hoverTriggerPanel: NSPanel
    private let presentation = NotchSurfacePresentation()
    private let destinationStore: DestinationStore
    private var vaultConfiguration: VaultConfiguration
    private let onComposerRequested: () -> Void
    private let onSettingsRequested: () -> Void

    private var hostingView: HoverHostingView?
    private var hoverTriggerView: HoverTriggerView?
    private var dwellWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var lastHandledCaptureState: CaptureComposerState?
    private var isStarted = false

    init(
        destinationStore: DestinationStore,
        vaultConfiguration: VaultConfiguration,
        onComposerRequested: @escaping () -> Void,
        onSettingsRequested: @escaping () -> Void
    ) {
        self.destinationStore = destinationStore
        self.vaultConfiguration = vaultConfiguration
        self.onComposerRequested = onComposerRequested
        self.onSettingsRequested = onSettingsRequested
        self.panel = KeyableNotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 196, height: 32),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.hoverTriggerPanel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: NotchComposerPanelLayout.compactSize.width,
                height: NotchComposerPanelLayout.compactSize.height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true

        hoverTriggerPanel.isOpaque = false
        hoverTriggerPanel.backgroundColor = .clear
        hoverTriggerPanel.hasShadow = false
        hoverTriggerPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hoverTriggerPanel.hidesOnDeactivate = false
        hoverTriggerPanel.isMovable = false
        hoverTriggerPanel.animationBehavior = .none
        hoverTriggerPanel.acceptsMouseMovedEvents = true

        // Apply the level last. NSPanel's floating-panel behavior can otherwise
        // reset the window to the regular floating layer and put it behind the menu bar.
        let notchLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.level = notchLevel
        hoverTriggerPanel.level = notchLevel
    }

    func start() {
        guard !isStarted, let screen = activeScreen else {
            return
        }

        isStarted = true
        installSurfaceIfNeeded()
        installHoverTriggerIfNeeded()
        presentation.safeTopInset = screen.safeAreaInsets.top
        presentation.showIdle()
        panel.setFrame(NotchGeometry.frame(for: NotchGeometry.idleSize(for: screen), on: screen), display: true)
        positionHoverTrigger(on: screen)
        panel.orderFrontRegardless()
        hoverTriggerPanel.orderFrontRegardless()
    }

    func stop() {
        guard isStarted else {
            return
        }

        isStarted = false
        cancelScheduledTransitions()
        lastHandledCaptureState = nil
        hoverTriggerPanel.orderOut(nil)
        panel.orderOut(nil)
        presentation.showIdle()
    }

    func showComposer(source: CaptureSource = .blank) {
        guard isStarted, let screen = activeScreen else {
            return
        }

        cancelScheduledTransitions()
        lastHandledCaptureState = nil
        hoverTriggerPanel.orderOut(nil)
        presentation.safeTopInset = screen.safeAreaInsets.top
        presentation.showComposer(
            CaptureComposerModel(
                source: source,
                vaultConfiguration: vaultConfiguration,
                destinationStore: destinationStore
            )
        )

        focusComposerPanel()
        transitionPanel(
            to: NotchComposerPanelLayout.composerSize,
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

    func updateVaultConfiguration(_ configuration: VaultConfiguration) {
        vaultConfiguration = configuration
        presentation.composerModel?.updateVaultConfiguration(configuration)
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
            },
            onCaptureStatusChanged: { [weak self] status in
                self?.captureStatusChanged(status)
            },
            onCaptureStateChanged: { [weak self] state in
                self?.captureStateChanged(state)
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

    private func installHoverTriggerIfNeeded() {
        guard hoverTriggerView == nil else {
            return
        }

        let triggerView = HoverTriggerView()
        triggerView.onMouseEntered = { [weak self] in
            self?.pointerEntered()
        }
        hoverTriggerPanel.contentView = triggerView
        hoverTriggerView = triggerView
    }

    private func positionHoverTrigger(on screen: NSScreen) {
        let frame = NotchGeometry.frame(for: NotchGeometry.peekSize(for: screen), on: screen)
        hoverTriggerPanel.setFrame(frame, display: true)
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
        positionHoverTrigger(on: screen)
        hoverTriggerPanel.orderFrontRegardless()
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
        hoverTriggerPanel.orderOut(nil)
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
            panel.resizeAnimationDuration = nil
            panel.setFrame(frame, display: true)
            return
        }

        // NSWindow animates the origin and size together when using its frame
        // animation API. Keeping this as one operation avoids a visible
        // vertical expansion followed by a delayed horizontal resize.
        panel.resizeAnimationDuration = duration
        panel.setFrame(frame, display: true, animate: true)
        panel.resizeAnimationDuration = nil
    }

    private func captureStatusChanged(_ status: CaptureComposerStatus) {
        let state = presentation.composerModel?.state ?? status.composerState
        captureStateChanged(state)
    }

    private func captureStateChanged(_ state: CaptureComposerState) {
        guard lastHandledCaptureState != state else {
            return
        }
        lastHandledCaptureState = state

        switch state {
        case .empty, .prepared:
            presentation.setCaptureState(.idle)
        case .saving:
            presentation.setCaptureState(.saving)
        case .done(let result):
            let rootURL = presentation.composerModel?.vaultConfiguration.rootURL
            let displayPath = rootURL.map {
                Self.displayPath(for: result.noteURL, relativeTo: $0)
            }
            presentation.setCaptureState(.done, path: displayPath)
        case .error:
            presentation.setCaptureState(.idle)
        }

        guard presentation.phase == .composer,
              let screen = activeScreen else {
            return
        }

        let size = state.errorMessage == nil
            ? NotchComposerPanelLayout.composerSize
            : NotchComposerPanelLayout.errorSize
        transitionPanel(
            to: size,
            on: screen,
            duration: NotchMetrics.composerDuration
        )
    }

    private static func displayPath(for fileURL: URL, relativeTo rootURL: URL) -> String {
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        let relativeComponents: [String]

        if fileComponents.starts(with: rootComponents) {
            relativeComponents = Array(fileComponents.dropFirst(rootComponents.count))
        } else {
            relativeComponents = Array(fileComponents.suffix(2))
        }

        return relativeComponents.suffix(2).joined(separator: "/")
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

enum NotchComposerPanelLayout {
    static let compactSize = CGSize(width: 224, height: 46)
    static let composerSize = CGSize(width: 312, height: 412)
    static let errorSize = CGSize(width: 312, height: 448)
    static let resizeDuration: TimeInterval = 0.30
}

private enum NotchMetrics {
    static let hoverDelay: TimeInterval = 0.10
    static let collapseDelay: TimeInterval = 0.10
    static let expandDuration: TimeInterval = 0.22
    static let collapseDuration: TimeInterval = 0.18
    static let composerDuration: TimeInterval = NotchComposerPanelLayout.resizeDuration
    static let composerCloseDuration: TimeInterval = 0.22
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
            return NotchComposerPanelLayout.compactSize
        }

        return NSSize(width: notchRect.width + 39, height: notchRect.height + 14)
    }

    static func frame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame

        // Every surface size shares the display's top edge. Resizing this
        // frame therefore grows downward from the notch instead of shifting
        // the cap while the composer opens.
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private final class KeyableNotchPanel: NSPanel {
    var resizeAnimationDuration: TimeInterval?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        resizeAnimationDuration ?? super.animationResizeTime(newFrame)
    }

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

private final class HoverTriggerView: NSView {
    var onMouseEntered: (() -> Void)?

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
}
