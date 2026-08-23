import SwiftUI

enum DiaryThemeChoice: String, CaseIterable, Codable, Identifiable, Sendable {
  case ink
  case paper
  case plum
  case moss

  var id: String { rawValue }

  var name: String {
    switch self {
    case .ink: "Ink"
    case .paper: "Black & white"
    case .plum: "Night plum"
    case .moss: "Forest"
    }
  }

  var detail: String {
    switch self {
    case .ink: "Graphite, sea glass, and coral"
    case .paper: "Warm paper and near-black ink"
    case .plum: "Muted aubergine with rose signal"
    case .moss: "Deep green with lichen signal"
    }
  }

  var palette: DiaryPalette {
    switch self {
    case .ink:
      DiaryPalette(
        canvas: Color(red: 17 / 255, green: 24 / 255, blue: 32 / 255),
        field: Color(red: 24 / 255, green: 35 / 255, blue: 44 / 255),
        elevated: Color(red: 30 / 255, green: 43 / 255, blue: 52 / 255),
        text: Color(red: 244 / 255, green: 240 / 255, blue: 232 / 255),
        secondaryText: Color(red: 168 / 255, green: 181 / 255, blue: 182 / 255),
        signal: Color(red: 120 / 255, green: 199 / 255, blue: 176 / 255),
        record: Color(red: 240 / 255, green: 120 / 255, blue: 94 / 255),
        controlInk: Color(red: 17 / 255, green: 24 / 255, blue: 32 / 255),
        hairline: Color.white.opacity(0.12)
      )
    case .paper:
      DiaryPalette(
        canvas: Color(red: 246 / 255, green: 244 / 255, blue: 238 / 255),
        field: Color(red: 231 / 255, green: 229 / 255, blue: 222 / 255),
        elevated: Color.white,
        text: Color(red: 20 / 255, green: 20 / 255, blue: 19 / 255),
        secondaryText: Color(red: 86 / 255, green: 86 / 255, blue: 81 / 255),
        signal: Color(red: 31 / 255, green: 31 / 255, blue: 29 / 255),
        record: Color(red: 12 / 255, green: 12 / 255, blue: 12 / 255),
        controlInk: Color.white,
        hairline: Color.black.opacity(0.14)
      )
    case .plum:
      DiaryPalette(
        canvas: Color(red: 28 / 255, green: 21 / 255, blue: 31 / 255),
        field: Color(red: 42 / 255, green: 31 / 255, blue: 45 / 255),
        elevated: Color(red: 50 / 255, green: 36 / 255, blue: 52 / 255),
        text: Color(red: 250 / 255, green: 241 / 255, blue: 244 / 255),
        secondaryText: Color(red: 193 / 255, green: 171 / 255, blue: 181 / 255),
        signal: Color(red: 221 / 255, green: 171 / 255, blue: 213 / 255),
        record: Color(red: 247 / 255, green: 126 / 255, blue: 109 / 255),
        controlInk: Color(red: 28 / 255, green: 21 / 255, blue: 31 / 255),
        hairline: Color.white.opacity(0.13)
      )
    case .moss:
      DiaryPalette(
        canvas: Color(red: 23 / 255, green: 31 / 255, blue: 24 / 255),
        field: Color(red: 33 / 255, green: 44 / 255, blue: 35 / 255),
        elevated: Color(red: 40 / 255, green: 52 / 255, blue: 42 / 255),
        text: Color(red: 242 / 255, green: 239 / 255, blue: 228 / 255),
        secondaryText: Color(red: 172 / 255, green: 186 / 255, blue: 169 / 255),
        signal: Color(red: 170 / 255, green: 204 / 255, blue: 119 / 255),
        record: Color(red: 229 / 255, green: 141 / 255, blue: 105 / 255),
        controlInk: Color(red: 23 / 255, green: 31 / 255, blue: 24 / 255),
        hairline: Color.white.opacity(0.12)
      )
    }
  }
}

enum CaptureVisualizationStyle: String, CaseIterable, Codable, Identifiable, Sendable {
  case waveform
  case rings
  case pixels

  var id: String { rawValue }

  var name: String {
    switch self {
    case .waveform: "Waveform"
    case .rings: "Signal rings"
    case .pixels: "Pixel meter"
    }
  }

  var symbolName: String {
    switch self {
    case .waveform: "waveform"
    case .rings: "dot.radiowaves.left.and.right"
    case .pixels: "square.grid.3x3.fill"
    }
  }
}

struct DiaryPalette: Sendable {
  let canvas: Color
  let field: Color
  let elevated: Color
  let text: Color
  let secondaryText: Color
  let signal: Color
  let record: Color
  let controlInk: Color
  let hairline: Color
}

private struct DiaryPaletteKey: EnvironmentKey {
  static let defaultValue = DiaryThemeChoice.ink.palette
}

extension EnvironmentValues {
  var diaryPalette: DiaryPalette {
    get { self[DiaryPaletteKey.self] }
    set { self[DiaryPaletteKey.self] = newValue }
  }
}

struct Hairline: View {
  @Environment(\.diaryPalette) private var palette

  var body: some View {
    Rectangle()
      .fill(palette.hairline)
      .frame(height: 1)
      .accessibilityHidden(true)
  }
}
