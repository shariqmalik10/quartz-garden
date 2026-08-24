import SwiftUI

enum DiaryThemeChoice: String, CaseIterable, Codable, Identifiable, Sendable {
  case ink
  case paper
  case plum
  case moss
  case dither
  case cobalt
  case solar
  case rosewood

  var id: String { rawValue }

  var name: String {
    switch self {
    case .ink: "Ink"
    case .paper: "Black & white"
    case .plum: "Night plum"
    case .moss: "Forest"
    case .dither: "Dither signal"
    case .cobalt: "Cobalt"
    case .solar: "Solar paper"
    case .rosewood: "Rosewood"
    }
  }

  var detail: String {
    switch self {
    case .ink: "Graphite, sea glass, and coral"
    case .paper: "Warm paper and near-black ink"
    case .plum: "Muted aubergine with rose signal"
    case .moss: "Deep green with lichen signal"
    case .dither: "Carbon, phosphor lime, and ordered pixels"
    case .cobalt: "Midnight blue with sky and marigold"
    case .solar: "Sun-warmed paper with petrol ink"
    case .rosewood: "Dark cherry with amber signal"
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
    case .dither:
      DiaryPalette(
        canvas: Color(red: 10 / 255, green: 10 / 255, blue: 11 / 255),
        field: Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255),
        elevated: Color(red: 27 / 255, green: 27 / 255, blue: 30 / 255),
        text: Color(red: 244 / 255, green: 244 / 255, blue: 235 / 255),
        secondaryText: Color(red: 174 / 255, green: 176 / 255, blue: 164 / 255),
        signal: Color(red: 188 / 255, green: 255 / 255, blue: 91 / 255),
        record: Color(red: 255 / 255, green: 92 / 255, blue: 122 / 255),
        controlInk: Color(red: 10 / 255, green: 10 / 255, blue: 11 / 255),
        hairline: Color.white.opacity(0.13)
      )
    case .cobalt:
      DiaryPalette(
        canvas: Color(red: 13 / 255, green: 23 / 255, blue: 45 / 255),
        field: Color(red: 20 / 255, green: 35 / 255, blue: 65 / 255),
        elevated: Color(red: 28 / 255, green: 46 / 255, blue: 79 / 255),
        text: Color(red: 243 / 255, green: 247 / 255, blue: 255 / 255),
        secondaryText: Color(red: 170 / 255, green: 187 / 255, blue: 218 / 255),
        signal: Color(red: 103 / 255, green: 201 / 255, blue: 255 / 255),
        record: Color(red: 255 / 255, green: 180 / 255, blue: 73 / 255),
        controlInk: Color(red: 13 / 255, green: 23 / 255, blue: 45 / 255),
        hairline: Color.white.opacity(0.13)
      )
    case .solar:
      DiaryPalette(
        canvas: Color(red: 247 / 255, green: 235 / 255, blue: 202 / 255),
        field: Color(red: 237 / 255, green: 218 / 255, blue: 174 / 255),
        elevated: Color(red: 255 / 255, green: 248 / 255, blue: 229 / 255),
        text: Color(red: 53 / 255, green: 40 / 255, blue: 24 / 255),
        secondaryText: Color(red: 112 / 255, green: 91 / 255, blue: 64 / 255),
        signal: Color(red: 32 / 255, green: 103 / 255, blue: 112 / 255),
        record: Color(red: 190 / 255, green: 71 / 255, blue: 43 / 255),
        controlInk: Color(red: 255 / 255, green: 248 / 255, blue: 229 / 255),
        hairline: Color.black.opacity(0.14)
      )
    case .rosewood:
      DiaryPalette(
        canvas: Color(red: 42 / 255, green: 22 / 255, blue: 26 / 255),
        field: Color(red: 59 / 255, green: 32 / 255, blue: 38 / 255),
        elevated: Color(red: 73 / 255, green: 42 / 255, blue: 48 / 255),
        text: Color(red: 249 / 255, green: 235 / 255, blue: 230 / 255),
        secondaryText: Color(red: 204 / 255, green: 174 / 255, blue: 169 / 255),
        signal: Color(red: 242 / 255, green: 186 / 255, blue: 105 / 255),
        record: Color(red: 255 / 255, green: 105 / 255, blue: 103 / 255),
        controlInk: Color(red: 42 / 255, green: 22 / 255, blue: 26 / 255),
        hairline: Color.white.opacity(0.13)
      )
    }
  }

  var usesDitherTexture: Bool { self == .dither }
}

enum CaptureVisualizationStyle: String, CaseIterable, Codable, Identifiable, Sendable {
  case waveform
  case rings
  case pixels
  case ribbon
  case radial
  case dither

  var id: String { rawValue }

  var name: String {
    switch self {
    case .waveform: "Waveform"
    case .rings: "Signal rings"
    case .pixels: "Pixel meter"
    case .ribbon: "Ribbon scope"
    case .radial: "Radial signal"
    case .dither: "Dither field"
    }
  }

  var symbolName: String {
    switch self {
    case .waveform: "waveform"
    case .rings: "dot.radiowaves.left.and.right"
    case .pixels: "square.grid.3x3.fill"
    case .ribbon: "waveform.path"
    case .radial: "sun.max.fill"
    case .dither: "circle.grid.3x3.fill"
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

struct DitherBackdrop: View {
  let color: Color

  var body: some View {
    Canvas(rendersAsynchronously: true) { context, size in
      let step: CGFloat = 5
      let matrix = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
      for y in stride(from: CGFloat.zero, through: size.height, by: step) {
        for x in stride(from: CGFloat.zero, through: size.width, by: step) {
          let column = Int(x / step)
          let row = Int(y / step)
          let threshold = matrix[(row % 4) * 4 + (column % 4)]
          guard threshold < 4 + ((row + column) % 3) else { continue }
          context.fill(
            Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)),
            with: .color(color)
          )
        }
      }
    }
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }
}
