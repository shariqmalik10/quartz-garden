import Foundation

public struct AudioMeterReading: Equatable, Sendable {
    public let averagePower: Float
    public let peakPower: Float

    public init(averagePower: Float, peakPower: Float) {
        self.averagePower = averagePower
        self.peakPower = peakPower
    }

    public static let silence = AudioMeterReading(averagePower: -.infinity, peakPower: -.infinity)
}

public enum AudioLevelMeter {
    /// Converts a recorder dBFS value into a perceptual 0...1 display level.
    /// Values below the noise floor are treated as silence and a square-root curve
    /// gives ordinary speaking volume enough visual range without clipping peaks.
    public static func normalizedLevel(
        decibels: Float,
        noiseFloor: Float = -60
    ) -> Double {
        guard decibels.isFinite, noiseFloor < 0 else { return 0 }
        let clamped = min(0, max(noiseFloor, decibels))
        let linear = pow(10, Double(clamped) / 20)
        let floorLinear = pow(10, Double(noiseFloor) / 20)
        let scaled = (linear - floorLinear) / (1 - floorLinear)
        return min(1, max(0, sqrt(scaled)))
    }
}

public struct WaveformBuffer: Equatable, Sendable {
    public let capacity: Int
    public private(set) var samples: [Double]

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.samples = []
    }

    public mutating func append(_ sample: Double) {
        samples.append(min(1, max(0, sample.isFinite ? sample : 0)))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }
}
