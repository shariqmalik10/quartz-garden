import SwiftUI

enum CaptureSurfaceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case notch
    case menuBar
    case both

    var id: Self { self }

    var title: String {
        switch self {
        case .notch:
            return "Notch"
        case .menuBar:
            return "Menu Bar"
        case .both:
            return "Both"
        }
    }

    var summary: String {
        switch self {
        case .notch:
            return "Hover the top-center notch to reveal Garden Drop."
        case .menuBar:
            return "Use the tray icon in the menu bar to capture."
        case .both:
            return "Use either the notch or the menu-bar tray icon."
        }
    }

    var symbolName: String {
        switch self {
        case .notch:
            return "rectangle.topthird.inset.filled"
        case .menuBar:
            return "menubar.arrow.up.rectangle"
        case .both:
            return "rectangle.topthird.inset.filled.and.cursorarrow"
        }
    }

    var showsMenuBar: Bool {
        self != .notch
    }

    var showsNotch: Bool {
        self != .menuBar
    }
}
