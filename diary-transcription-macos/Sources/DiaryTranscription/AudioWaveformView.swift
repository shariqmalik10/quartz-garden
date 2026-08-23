import SwiftUI

struct AudioWaveformView: View {
    @Bindable var capture: AudioCaptureModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barCount = 31

    var body: some View {
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
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78),
                value: values
            )
        }
        .frame(height: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(capture.isRecording ? "Live microphone level" : "Recorded sound waveform")
        .accessibilityValue(accessibilityValue)
    }

    private var displayValues: [Double] {
        let live = capture.samples.suffix(barCount)
        let paddingCount = max(0, barCount - live.count)
        let quietPattern = (0..<paddingCount).map { index in
            0.035 + Double((index * 7) % 5) * 0.009
        }
        return quietPattern + live
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
        return DiaryDesign.signal.opacity(opacity)
    }
}
