import AppKit
import Carbon.HIToolbox
import Foundation
import Observation
import SwiftUI

struct GlobalKeyBinding: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let displayName: String
}

enum GlobalShortcutError: LocalizedError {
    case eventHandlerFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .eventHandlerFailed(status):
            "The global shortcut service could not start (macOS status \(status))."
        case let .registrationFailed(status):
            "That shortcut could not be registered (macOS status \(status)). It may already be used by another app."
        }
    }
}

@MainActor
final class GlobalShortcutController {
    nonisolated(unsafe) private var eventHandler: EventHandlerRef?
    nonisolated(unsafe) private var hotKey: EventHotKeyRef?
    private var action: (() -> Void)?
    private var currentBinding: GlobalKeyBinding?
    private let signature: OSType = 0x44545259 // DTRY
    private var nextIdentifier: UInt32 = 1

    init() {}

    private func installHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }
        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return noErr }
                let controller = Unmanaged<GlobalShortcutController>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                Task { @MainActor in controller.action?() }
                return noErr
            },
            1,
            &type,
            context,
            &eventHandler
        )
        guard status == noErr, eventHandler != nil else {
            throw GlobalShortcutError.eventHandlerFailed(status)
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func register(_ binding: GlobalKeyBinding?, action: @escaping () -> Void) throws {
        try installHandlerIfNeeded()
        if binding == currentBinding {
            self.action = action
            return
        }
        guard let binding else {
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = nil
            currentBinding = nil
            self.action = action
            return
        }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: signature, id: nextIdentifier)
        let result = RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard result == noErr, let reference else {
            throw GlobalShortcutError.registrationFailed(result)
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = reference
        currentBinding = binding
        self.action = action
        nextIdentifier = nextIdentifier == 1 ? 2 : 1
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var binding: GlobalKeyBinding?

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.binding = binding
        view.onChange = { binding = $0 }
        return view
    }

    func updateNSView(_ view: ShortcutRecorderNSView, context: Context) {
        view.binding = binding
        view.onChange = { binding = $0 }
        view.needsDisplay = true
    }
}

final class ShortcutRecorderNSView: NSView {
    var binding: GlobalKeyBinding?
    var onChange: ((GlobalKeyBinding?) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 250, height: 34) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .exterior
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityHelp("Press to record a global keyboard shortcut. Delete clears the shortcut.")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        focusRingType = .exterior
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityHelp("Press to record a global keyboard shortcut. Delete clears the shortcut.")
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            onChange?(nil)
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard Self.isSafeBinding(keyCode: event.keyCode, flags: flags) else {
            NSSound.beep()
            return
        }
        let name = Self.displayName(for: event, flags: flags)
        onChange?(GlobalKeyBinding(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: Self.carbonModifiers(for: flags),
            displayName: name
        ))
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let focused = window?.firstResponder === self
        let bounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        (focused ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        shape.fill()
        (focused ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        shape.lineWidth = focused ? 2 : 1
        shape.stroke()

        let value = focused ? "Type a shortcut…" : (binding?.displayName ?? "None")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: binding == nil ? .regular : .medium),
            .foregroundColor: focused || binding == nil ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let text = NSAttributedString(string: value, attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: 10, y: (bounds.height - size.height) / 2))
    }

    override func accessibilityLabel() -> String? { "Global recording shortcut" }
    override func accessibilityValue() -> Any? { binding?.displayName ?? "None" }
    override func accessibilityPerformPress() -> Bool {
        window?.makeFirstResponder(self)
        needsDisplay = true
        return true
    }

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    static func isSafeBinding(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard !modifierKeyCodes.contains(keyCode) else { return false }
        guard !flags.intersection([.command, .control, .option]).isEmpty else { return false }

        let modifierCount = [NSEvent.ModifierFlags.command, .control, .option, .shift]
            .filter(flags.contains)
            .count
        guard modifierCount >= 2 else { return false }

        let commandOnlyFamily = flags.contains(.command)
            && !flags.contains(.control)
            && !flags.contains(.option)
        let reservedCommandKeys: Set<UInt16> = [
            0, 1, 3, 6, 7, 8, 9, 12, 13, 31, 35, 45, 48, 49
        ]
        return !(commandOnlyFamily && reservedCommandKeys.contains(keyCode))
    }

    private static func carbonModifiers(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    private static func displayName(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += keyName(for: event)
        return result
    }

    private static func keyName(for event: NSEvent) -> String {
        let special: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        if let name = special[event.keyCode] { return name }
        let value = event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        return value.isEmpty ? "Key \(event.keyCode)" : value
    }
}
