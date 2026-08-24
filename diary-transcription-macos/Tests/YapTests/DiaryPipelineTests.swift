import DiaryCore
import Foundation
import XCTest

@testable import Yap

@MainActor
final class DiaryPipelineTests: XCTestCase {
  func testCohereINT8EndToEndWhenEnabled() async throws {
    guard ProcessInfo.processInfo.environment["DIARY_COHERE_E2E"] == "1",
      let audioPath = ProcessInfo.processInfo.environment["DIARY_COHERE_AUDIO"],
      !audioPath.isEmpty
    else {
      throw XCTSkip("Set DIARY_COHERE_E2E=1 and DIARY_COHERE_AUDIO to run the 2.42 GB model test")
    }

    var installer: CohereTranscriptionEngine? = CohereTranscriptionEngine()
    let clock = ContinuousClock()
    let installStart = clock.now
    try await installer!.install { _ in }
    let installDuration = installStart.duration(to: clock.now)
    installer = nil

    let engine = CohereTranscriptionEngine()
    try await engine.prepareOffline()
    let inferenceStart = clock.now
    let text = try await engine.transcribe(
      audioURL: URL(fileURLWithPath: audioPath),
      language: "en"
    )
    let inferenceDuration = inferenceStart.duration(to: clock.now)

    print("Cohere INT8 install/load: \(installDuration)")
    print("Cohere INT8 inference: \(inferenceDuration)")
    print("Cohere INT8 transcript: \(text)")
    XCTAssertFalse(text.isEmpty)
  }

  func testDefaultShortcutIsDisabled() {
    let suite = "DiaryPipelineTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let model = DiaryAppModel(
      transcriber: FakeTranscriptionEngine(),
      defaults: defaults
    )

    XCTAssertNil(model.shortcut)
  }

  func testUnsupportedPersistedLanguageFallsBackToEnglish() {
    let suite = "DiaryPipelineTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("hi", forKey: "DiaryTranscription.language")

    let model = DiaryAppModel(
      transcriber: FakeTranscriptionEngine(),
      defaults: defaults
    )

    XCTAssertEqual(model.languageCode, "en")
    XCTAssertEqual(defaults.string(forKey: "DiaryTranscription.language"), "en")
  }

  func testFailedBackgroundWarmupLeavesRetryableFailureState() async throws {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = PipelineAudioSession()
    let capture = AudioCaptureModel(
      session: session,
      store: PendingAudioStore(baseDirectory: root),
      automaticMetering: false
    )
    let model = DiaryAppModel(
      capture: capture,
      transcriber: FakeTranscriptionEngine(prepareError: TestEngineError.warmupFailed),
      defaults: UserDefaults(suiteName: "DiaryPipelineTests-\(UUID().uuidString)")!
    )
    model.vaultPath = root.path

    await model.handlePrimaryAction()
    try await Task.sleep(for: .milliseconds(30))

    guard case .failed = model.modelState else {
      return XCTFail("Expected warmup to become a visible failure")
    }
    session.time = 1
    capture.refreshMeter()
    await model.handlePrimaryAction()
    guard case .failed = model.workflowState else {
      return XCTFail("Expected the pending recording to remain retryable")
    }
    XCTAssertNotNil(capture.capturedURL)
  }

  func testRecordTranscribeAppendDeletesAudioOnlyAfterSave() async throws {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vault = root.appendingPathComponent("Vault", isDirectory: true)
    try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
    let writer = DiaryWriter()
    try await writer.configureVault(vault)

    let session = PipelineAudioSession()
    let capture = AudioCaptureModel(
      session: session,
      store: PendingAudioStore(baseDirectory: root),
      automaticMetering: false
    )
    let defaults = UserDefaults(suiteName: "DiaryPipelineTests-\(UUID().uuidString)")!
    let model = DiaryAppModel(
      writer: writer,
      capture: capture,
      transcriber: FakeTranscriptionEngine(text: "A thought captured locally."),
      pendingStore: PendingTranscriptionStore(),
      defaults: defaults
    )
    model.vaultPath = vault.path

    await model.handlePrimaryAction()
    let audioURL = try XCTUnwrap(capture.capturedURL)
    XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
    session.time = 1.2
    capture.refreshMeter()

    await model.handlePrimaryAction()

    guard case .saved(let fileName, let preview) = model.workflowState else {
      return XCTFail("Expected completed workflow, got \(model.workflowState)")
    }
    XCTAssertTrue(fileName.hasPrefix("diary-log_"))
    XCTAssertEqual(preview, "A thought captured locally.")
    XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    XCTAssertNil(capture.capturedURL)

    let diary = vault.appendingPathComponent("Diary").appendingPathComponent(fileName)
    let contents = try String(contentsOf: diary, encoding: .utf8)
    XCTAssertTrue(contents.contains("A thought captured locally."))
    XCTAssertTrue(contents.contains("<!-- diary-transcription:"))
  }

  func testWriteFailureRetainsAudioAndTranscriptForRetry() async throws {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vault = root.appendingPathComponent("Vault", isDirectory: true)
    try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
    let writer = DiaryWriter()
    let session = PipelineAudioSession()
    let capture = AudioCaptureModel(
      session: session,
      store: PendingAudioStore(baseDirectory: root),
      automaticMetering: false
    )
    let transcriber = FakeTranscriptionEngine(text: "Retry-safe transcript.")
    let model = DiaryAppModel(
      writer: writer,
      capture: capture,
      transcriber: transcriber,
      defaults: UserDefaults(suiteName: "DiaryPipelineTests-\(UUID().uuidString)")!
    )
    model.vaultPath = vault.path

    await model.handlePrimaryAction()
    session.time = 1
    capture.refreshMeter()
    await model.handlePrimaryAction()

    let audioURL = try XCTUnwrap(capture.capturedURL)
    XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
    guard case .failed = model.workflowState else {
      return XCTFail("Expected recoverable write failure")
    }
    let pending = try XCTUnwrap(PendingTranscriptionStore().load(for: audioURL))
    XCTAssertEqual(pending.transcript, "Retry-safe transcript.")

    try await writer.configureVault(vault)
    await model.retryPendingRecording()

    guard case .saved = model.workflowState else {
      return XCTFail("Expected retry to save")
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    let transcriptionCount = await transcriber.transcriptionCount
    XCTAssertEqual(transcriptionCount, 1, "Retry should reuse the durable transcript")
  }

  func testRecordingContinuesSelectedWritingFileAndRecordsVoiceStats() async throws {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let vault = root.appendingPathComponent("Vault", isDirectory: true)
    try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
    let writer = DiaryWriter()
    try await writer.configureVault(vault)
    let draftURL = vault.appendingPathComponent("Writing/long-thought.md")
    try await writer.createWritingDraft(at: draftURL, title: "Long Thought")

    let session = PipelineAudioSession()
    let capture = AudioCaptureModel(
      session: session,
      store: PendingAudioStore(baseDirectory: root),
      automaticMetering: false
    )
    let suite = "DiaryPipelineTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DiaryAppModel(
      writer: writer,
      capture: capture,
      transcriber: FakeTranscriptionEngine(text: "A second piece of the same essay."),
      pendingStore: PendingTranscriptionStore(),
      defaults: defaults
    )
    model.vaultPath = vault.path
    model.entryDestination = .existing(relativePath: "Writing/long-thought.md")

    await model.handlePrimaryAction()
    session.time = 64
    capture.refreshMeter()
    await model.handlePrimaryAction()

    guard case .saved(let fileName, _) = model.workflowState else {
      return XCTFail("Expected selected draft to save")
    }
    XCTAssertEqual(fileName, "long-thought.md")
    let contents = try String(contentsOf: draftURL, encoding: .utf8)
    XCTAssertTrue(contents.contains("A second piece of the same essay."))
    XCTAssertFalse(contents.contains("# Diary Log"))
    XCTAssertEqual(model.usageStats.voiceEntries, 1)
    XCTAssertEqual(model.usageStats.audioSeconds, 64, accuracy: 0.001)
    XCTAssertEqual(
      defaults.string(forKey: "DiaryTranscription.destinationRelativePath"),
      "Writing/long-thought.md"
    )
  }

  private func makeTemporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("DiaryPipelineTests-\(UUID().uuidString)", isDirectory: true)
  }
}

private actor FakeTranscriptionEngine: LocalTranscriptionEngine {
  nonisolated let isInstalled = true
  nonisolated let modelDirectory = FileManager.default.temporaryDirectory
  private let text: String
  private let prepareError: TestEngineError?
  private(set) var transcriptionCount = 0

  init(text: String = "Transcript", prepareError: TestEngineError? = nil) {
    self.text = text
    self.prepareError = prepareError
  }
  func install(progress: @MainActor @escaping @Sendable (Double) -> Void) async throws {
    await progress(1)
  }
  func prepareOffline() async throws {
    if let prepareError { throw prepareError }
  }
  func transcribe(audioURL: URL, language: String) async throws -> String {
    transcriptionCount += 1
    return text
  }
  func removeInstalledModel() async throws {}
}

private enum TestEngineError: LocalizedError {
  case warmupFailed

  var errorDescription: String? { "Model warmup failed for testing." }
}

@MainActor
private final class PipelineAudioSession: AudioRecordingSession {
  var time: TimeInterval = 0
  var onUnexpectedEnd: ((AudioSessionEnd) -> Void)?
  var currentTime: TimeInterval { time }

  func requestPermission() async -> MicrophonePermission { .allowed }
  func startRecording(to url: URL) throws { try Data("audio".utf8).write(to: url) }
  func stopRecording() {}
  func meterReading() -> AudioMeterReading {
    AudioMeterReading(averagePower: -18, peakPower: -8)
  }
}
