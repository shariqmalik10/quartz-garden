import SwiftUI

struct AudioVisualizationView: View {
  @Bindable var capture: AudioCaptureModel
  let style: CaptureVisualizationStyle
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.diaryPalette) private var palette

  private let barCount = 31

  var body: some View {
    Group {
      switch style {
      case .waveform:
        waveform
      case .rings:
        rings
      case .pixels:
        pixelMeter
      case .ribbon:
        ribbonScope
      case .radial:
        radialSignal
      case .dither:
        ditherField
      }
    }
    .frame(height: 100)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      capture.isRecording ? "Live microphone level" : "Sound capture visualization"
    )
    .accessibilityValue(accessibilityValue)
  }

  private var waveform: some View {
    GeometryReader { proxy in
      let values = displayValues
      HStack(alignment: .center, spacing: 4) {
        ForEach(values.indices, id: \.self) { index in
          Capsule(style: .continuous)
            .fill(barColor(for: index, count: values.count))
            .frame(
              width: max(3, (proxy.size.width - CGFloat(barCount - 1) * 4) / CGFloat(barCount)),
              height: barHeight(values[index], available: proxy.size.height)
            )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(
        reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82),
        value: values
      )
    }
  }

  private var rings: some View {
    ZStack {
      ForEach(0..<4, id: \.self) { index in
        let diameter = CGFloat(34 + index * 17)
        Circle()
          .stroke(
            palette.signal.opacity(0.72 - Double(index) * 0.13),
            lineWidth: index == 0 ? 3 : 2
          )
          .frame(width: diameter, height: diameter)
          .scaleEffect(1 + CGFloat(signalLevel) * CGFloat(index + 1) * 0.055)
      }
      Circle()
        .fill(palette.signal)
        .frame(width: 12, height: 12)
        .scaleEffect(0.86 + CGFloat(signalLevel) * 0.44)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: signalLevel)
  }

  private var pixelMeter: some View {
    GeometryReader { proxy in
      let values = Array(displayValues.suffix(17))
      let columns = values.count
      let rows = 7
      let gap: CGFloat = 4
      let square = min(
        10,
        (proxy.size.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
      )
      HStack(alignment: .bottom, spacing: gap) {
        ForEach(values.indices, id: \.self) { column in
          VStack(spacing: gap) {
            ForEach((0..<rows).reversed(), id: \.self) { row in
              let threshold = Double(row + 1) / Double(rows + 1)
              Rectangle()
                .fill(
                  values[column] >= threshold
                    ? palette.signal
                    : palette.signal.opacity(0.12)
                )
                .frame(width: square, height: square)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: values)
    }
  }

  private var ribbonScope: some View {
    GeometryReader { proxy in
      let values = displayValues
      ZStack {
        ribbonPath(values: values, size: proxy.size, amplitude: 0.72)
          .stroke(
            palette.signal.opacity(0.24),
            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
          )
        ribbonPath(values: values, size: proxy.size, amplitude: 0.72)
          .stroke(
            palette.signal,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
        ribbonPath(values: Array(values.reversed()), size: proxy.size, amplitude: -0.45)
          .stroke(
            palette.record.opacity(0.56),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
          )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(
        reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.84),
        value: values
      )
    }
  }

  private var radialSignal: some View {
    let values = Array(displayValues.suffix(24))
    return ZStack {
      Circle()
        .stroke(palette.signal.opacity(0.14), lineWidth: 1)
        .frame(width: 48, height: 48)
      ForEach(values.indices, id: \.self) { index in
        let value = values[index]
        Capsule(style: .continuous)
          .fill(index.isMultiple(of: 5) ? palette.record : palette.signal)
          .frame(width: 3, height: 8 + CGFloat(value) * 25)
          .offset(y: -34 - CGFloat(value) * 7)
          .rotationEffect(.degrees(Double(index) / Double(values.count) * 360))
          .opacity(0.38 + value * 0.62)
      }
      Circle()
        .fill(palette.signal)
        .frame(width: 11, height: 11)
        .scaleEffect(0.82 + signalLevel * 0.48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: values)
  }

  private var ditherField: some View {
    GeometryReader { proxy in
      let columns = 28
      let rows = 11
      let gap: CGFloat = 3
      let cell = min(
        7,
        (proxy.size.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
      )
      let values = displayValues
      let bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
      VStack(spacing: gap) {
        ForEach(0..<rows, id: \.self) { row in
          HStack(spacing: gap) {
            ForEach(0..<columns, id: \.self) { column in
              let value = values[min(values.count - 1, column * values.count / columns)]
              let verticalLevel = Double(rows - row) / Double(rows)
              let threshold = Double(bayer[(row % 4) * 4 + (column % 4)]) / 16
              let active = value * 0.88 + threshold * 0.3 >= verticalLevel
              Rectangle()
                .fill(active ? palette.signal : palette.signal.opacity(0.08))
                .frame(width: cell, height: cell)
                .opacity(active && column.isMultiple(of: 7) ? 0.66 : 1)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.11), value: values)
    }
  }

  private var displayValues: [Double] {
    let live = capture.samples.suffix(barCount)
    let paddingCount = max(0, barCount - live.count)
    let quietPattern = (0..<paddingCount).map { index in
      0.035 + Double((index * 7) % 5) * 0.009
    }
    return quietPattern + live
  }

  private var signalLevel: Double {
    if capture.isRecording { return capture.inputLevel }
    return capture.samples.suffix(8).max() ?? 0.05
  }

  private var accessibilityValue: String {
    guard capture.isRecording else {
      return capture.samples.isEmpty ? "No recording yet" : "Recording captured"
    }
    return switch capture.inputLevel {
    case ..<0.16: "Very quiet"
    case ..<0.38: "Quiet"
    case ..<0.68: "Clear"
    default: "Loud"
    }
  }

  private func barHeight(_ value: Double, available: CGFloat) -> CGFloat {
    let minimum: CGFloat = 5
    let usable = max(0, available - minimum)
    return minimum + usable * CGFloat(pow(value, 0.78))
  }

  private func barColor(for index: Int, count: Int) -> Color {
    let recency = Double(index + 1) / Double(count)
    let opacity = capture.isRecording ? 0.35 + recency * 0.65 : 0.28 + recency * 0.42
    return palette.signal.opacity(opacity)
  }

  private func ribbonPath<S: Collection>(
    values: S,
    size: CGSize,
    amplitude: CGFloat
  ) -> Path where S.Element == Double, S.Index == Int {
    var path = Path()
    guard values.count > 1 else { return path }
    let centerY = size.height / 2
    for index in values.indices {
      let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
      let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
      let y = centerY + direction * CGFloat(values[index]) * centerY * amplitude
      if index == values.startIndex {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }
    return path
  }
}
