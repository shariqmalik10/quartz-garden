import AppKit
import DiaryCore
import SwiftUI
import XCTest

@testable import DiaryTranscription

@MainActor
final class MenuBarRenderingTests: XCTestCase {
  func testFirstViewportRendersAtMenuBarWidth() throws {
    let capture = AudioCaptureModel(
      session: SnapshotAudioRecordingSession(),
      store: PendingAudioStore(
        baseDirectory: FileManager.default.temporaryDirectory
          .appendingPathComponent("DiarySnapshot-\(UUID().uuidString)")),
      automaticMetering: false
    )
    let renderer = ImageRenderer(
      content: MenuBarContentView(
        model: DiaryAppModel(capture: capture)
      ))
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 404, height: nil)

    let image = try XCTUnwrap(renderer.cgImage)
    XCTAssertEqual(image.width, 840)
    XCTAssertGreaterThan(image.height, 700)
    assertFirstViewportStructure(in: image)

    if let outputPath = ProcessInfo.processInfo.environment["DIARY_SNAPSHOT_PATH"] {
      let representation = NSBitmapImageRep(cgImage: image)
      let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
      try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
  }

  func testListeningViewportRendersWithLiveSignal() async throws {
    let session = SnapshotAudioRecordingSession()
    let capture = AudioCaptureModel(
      session: session,
      store: PendingAudioStore(
        baseDirectory: FileManager.default.temporaryDirectory
          .appendingPathComponent("DiarySnapshot-\(UUID().uuidString)")),
      automaticMetering: false
    )
    let model = DiaryAppModel(capture: capture)
    model.vaultPath = "/tmp/Notes Vault"
    model.modelState = .ready
    model.visualizationStyle = .dither

    await capture.startRecording()
    for index in 0..<31 {
      session.reading = AudioMeterReading(
        averagePower: Float(-42 + (index * 17) % 34),
        peakPower: Float(-24 + (index * 11) % 20)
      )
      session.time = 12.4
      capture.refreshMeter()
    }

    let renderer = ImageRenderer(content: MenuBarContentView(model: model))
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 404, height: nil)
    let image = try XCTUnwrap(renderer.cgImage)
    capture.stopRecording()

    XCTAssertEqual(image.width, 840)
    XCTAssertGreaterThan(image.height, 700)
    assertFirstViewportStructure(in: image)

    if let outputPath = ProcessInfo.processInfo.environment["DIARY_RECORDING_SNAPSHOT_PATH"] {
      let representation = NSBitmapImageRep(cgImage: image)
      let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
      try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
  }

  func testWritingAndStatsModesRenderAtStableWidth() throws {
    let capture = AudioCaptureModel(
      session: SnapshotAudioRecordingSession(),
      store: PendingAudioStore(
        baseDirectory: FileManager.default.temporaryDirectory
          .appendingPathComponent("DiarySnapshot-\(UUID().uuidString)")),
      automaticMetering: false
    )
    let model = DiaryAppModel(capture: capture)
    model.vaultPath = "/tmp/Notes Vault"
    model.modelState = .ready
    var stats = DiaryUsageStats()
    for offset in 0..<14 {
      let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
      let repeatedWords = Array(
        repeating: "thought",
        count: 8 + ((offset * 13) % 47)
      ).joined(separator: " ")
      stats.record(
        entryID: "snapshot-entry-\(offset)",
        text: repeatedWords,
        audioDuration: offset.isMultiple(of: 2) ? 32 + Double(offset * 4) : nil,
        date: date
      )
    }
    model.usageStats = stats

    for mode in [DiaryMode.write, .stats] {
      model.themeChoice = mode == .stats ? .dither : .ink
      let renderer = ImageRenderer(
        content: MenuBarContentView(
          model: model,
          initialMode: mode
        ))
      renderer.scale = 2
      renderer.proposedSize = ProposedViewSize(width: 420, height: nil)
      let image = try XCTUnwrap(renderer.cgImage)
      XCTAssertEqual(image.width, 840)
      XCTAssertGreaterThan(image.height, 600)
      assertFirstViewportStructure(in: image)

      let environmentKey =
        mode == .write
        ? "DIARY_WRITING_SNAPSHOT_PATH"
        : "DIARY_STATS_SNAPSHOT_PATH"
      if let outputPath = ProcessInfo.processInfo.environment[environmentKey] {
        let representation = NSBitmapImageRep(cgImage: image)
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
      }
    }
  }

  func testDestinationStudioRendersBlogWorkflow() throws {
    let model = DiaryAppModel(
      capture: AudioCaptureModel(
        session: SnapshotAudioRecordingSession(),
        store: PendingAudioStore(
          baseDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("DiaryDestinationSnapshot-\(UUID().uuidString)")),
        automaticMetering: false
      )
    )
    model.vaultPath = "/tmp/Notes Vault"
    model.modelState = .ready
    model.themeChoice = .dither

    let renderer = ImageRenderer(
      content: DestinationStudioView(
        model: model,
        workspace: .constant(.blog),
        dismiss: {}
      )
      .environment(\.diaryPalette, DiaryThemeChoice.dither.palette)
    )
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 356, height: nil)
    let image = try XCTUnwrap(renderer.cgImage)
    XCTAssertEqual(image.width, 712)
    XCTAssertGreaterThan(image.height, 500)

    if let outputPath = ProcessInfo.processInfo.environment["DIARY_DESTINATION_SNAPSHOT_PATH"] {
      let representation = NSBitmapImageRep(cgImage: image)
      let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
      try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
  }

  private func assertFirstViewportStructure(in image: CGImage) {
    XCTAssertGreaterThan(
      distinctPixelCount(in: image, yRange: 0..<150), 12, "Header lost its visual content")
    XCTAssertGreaterThan(
      distinctPixelCount(in: image, yRange: 180..<min(image.height, 820)),
      20,
      "Capture field lost its waveform or primary action"
    )
    XCTAssertGreaterThan(
      distinctPixelCount(in: image, yRange: max(0, image.height - 120)..<image.height),
      12,
      "Footer lost its controls"
    )
  }

  private func distinctPixelCount(in image: CGImage, yRange: Range<Int>) -> Int {
    guard let data = image.dataProvider?.data,
      let bytes = CFDataGetBytePtr(data)
    else {
      return 0
    }
    let bytesPerPixel = max(1, image.bitsPerPixel / 8)
    var pixels = Set<UInt32>()
    for y in stride(from: yRange.lowerBound, to: yRange.upperBound, by: 4) {
      for x in stride(from: 0, to: image.width, by: 4) {
        let offset = y * image.bytesPerRow + x * bytesPerPixel
        var value: UInt32 = 0
        for component in 0..<min(4, bytesPerPixel) {
          value = (value << 8) | UInt32(bytes[offset + component])
        }
        pixels.insert(value)
      }
    }
    return pixels.count
  }
}

@MainActor
private final class SnapshotAudioRecordingSession: AudioRecordingSession {
  var time: TimeInterval = 0
  var reading = AudioMeterReading.silence
  var onUnexpectedEnd: ((AudioSessionEnd) -> Void)?

  var currentTime: TimeInterval { time }
  func requestPermission() async -> MicrophonePermission { .allowed }
  func startRecording(to url: URL) throws {}
  func stopRecording() {}
  func meterReading() -> AudioMeterReading { reading }
}
