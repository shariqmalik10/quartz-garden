import XCTest
@testable import DiaryCore

final class AudioMeteringTests: XCTestCase {
    func testLevelClampsSilenceAndFullScale() {
        XCTAssertEqual(AudioLevelMeter.normalizedLevel(decibels: -.infinity), 0)
        XCTAssertEqual(AudioLevelMeter.normalizedLevel(decibels: -80), 0)
        XCTAssertEqual(AudioLevelMeter.normalizedLevel(decibels: 0), 1, accuracy: 0.000_001)
    }

    func testLevelIsMonotonicAcrossSpeakingRange() {
        let quiet = AudioLevelMeter.normalizedLevel(decibels: -42)
        let speaking = AudioLevelMeter.normalizedLevel(decibels: -22)
        let loud = AudioLevelMeter.normalizedLevel(decibels: -6)

        XCTAssertLessThan(quiet, speaking)
        XCTAssertLessThan(speaking, loud)
    }

    func testWaveformBufferRetainsNewestBoundedSamples() {
        var buffer = WaveformBuffer(capacity: 3)
        buffer.append(0.1)
        buffer.append(0.2)
        buffer.append(0.3)
        buffer.append(0.4)

        XCTAssertEqual(buffer.samples, [0.2, 0.3, 0.4])
    }

    func testWaveformBufferSanitizesInputAndResets() {
        var buffer = WaveformBuffer(capacity: 3)
        buffer.append(-2)
        buffer.append(.infinity)
        buffer.append(4)

        XCTAssertEqual(buffer.samples, [0, 0, 1])
        buffer.reset()
        XCTAssertTrue(buffer.samples.isEmpty)
    }
}
