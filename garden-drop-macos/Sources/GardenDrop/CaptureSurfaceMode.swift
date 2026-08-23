import SwiftUI

enum CaptureSurfaceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case menuBar
    case both

    var id: Self { self }

    var title: String {
        switch self {
        case .menuBar:
            return "Menu Bar Only"
        case .both:
            return "Menu Bar + Notch"
        }
    }

    var summary: String {
        switch self {
        case .menuBar:
            return "Garden Drop stays available from the menu bar."
        case .both:
            return "Use the menu bar anytime, with the notch as an optional shortcut."
        }
    }

    var symbolName: String {
        switch self {
        case .menuBar:
            return "menubar.arrow.up.rectangle"
        case .both:
            return "rectangle.topthird.inset.filled.and.cursorarrow"
        }
    }

    var showsMenuBar: Bool {
        true
    }

    var showsNotch: Bool {
        self == .both
    }

    static func migrated(from storedValue: String?) -> CaptureSurfaceMode {
        switch storedValue {
        case CaptureSurfaceMode.both.rawValue, "notch":
            return .both
        default:
            return .menuBar
        }
    }
}
