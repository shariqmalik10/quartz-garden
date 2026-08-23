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
}
