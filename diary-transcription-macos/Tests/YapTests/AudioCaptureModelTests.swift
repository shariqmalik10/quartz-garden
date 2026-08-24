import DiaryCore
import Foundation
import XCTest
@testable import Yap

@MainActor
final class AudioCaptureModelTests: XCTestCase {
    func testDeniedPermissionProducesRecoveryStateWithoutStarting() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = FakeAudioRecordingSession(permission: .denied)
        let model = AudioCaptureModel(
            session: session,
            store: PendingAudioStore(baseDirectory: root),
            automaticMetering: false
        )

        await model.startRecording()

        XCTAssertEqual(model.phase, .permissionDenied)
        XCTAssertNil(session.startedURL)
        XCTAssertNil(model.capturedURL)
    }

    func testMeteringStopAndExplicitDiscardPreserveLifecycle() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = FakeAudioRecordingSession(permission: .allowed)
        let model = AudioCaptureModel(
            session: session,
            store: PendingAudioStore(baseDirectory: root),
            automaticMetering: false
        )

        await model.startRecording()
        XCTAssertEqual(model.phase, .recording)
        let recordingURL = try XCTUnwrap(model.capturedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))

        session.reading = AudioMeterReading(averagePower: -18, peakPower: -8)
        session.time = 4.8
        model.refreshMeter()
        XCTAssertEqual(model.samples.count, 1)
        XCTAssertGreaterThan(model.inputLevel, 0)
        XCTAssertEqual(model.formattedDuration, "00:04")

        model.stopRecording()
        XCTAssertEqual(model.phase, .captured)
        XCTAssertFalse(session.isRecording)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))

        model.discardRecording()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.capturedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordingURL.path))
    }

    func testUnreadablePendingRecordingIsSurfacedForRecovery() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PendingAudioStore(baseDirectory: root)
        let recordingURL = try store.makeRecordingURL()
        try Data("pending".utf8).write(to: recordingURL)

        let model = AudioCaptureModel(
            session: FakeAudioRecordingSession(permission: .allowed),
            store: store
        )

        guard case .interrupted = model.phase else {
            return XCTFail("Expected unreadable pending audio to need attention")
        }
        XCTAssertEqual(model.capturedURL?.standardizedFileURL, recordingURL.standardizedFileURL)
    }

    func testUnexpectedRecorderFailureRetainsFileAndLeavesListeningState() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = FakeAudioRecordingSession(permission: .allowed)
        let model = AudioCaptureModel(
            session: session,
            store: PendingAudioStore(baseDirectory: root),
            automaticMetering: false
        )

        await model.startRecording()
        let recordingURL = try XCTUnwrap(model.capturedURL)
        session.onUnexpectedEnd?(.failed("Input disconnected."))

        XCTAssertEqual(model.phase, .interrupted("Input disconnected."))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
        model.discardRecording()
        XCTAssertEqual(model.phase, .idle)
    }

    func testStartFailureCleansDestinationCreatedByRecorder() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = FakeAudioRecordingSession(permission: .allowed)
        session.failsWhenStarting = true
        let model = AudioCaptureModel(
            session: session,
            store: PendingAudioStore(baseDirectory: root),
            automaticMetering: false
        )

        await model.startRecording()

        guard case .failed = model.phase else {
            return XCTFail("Expected capture start to fail")
        }
        let attemptedURL = try XCTUnwrap(session.startedURL)
        XCTAssertNil(model.capturedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attemptedURL.path))
    }

    func testSubsecondDurationIsPreservedWhenRecordingStops() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = FakeAudioRecordingSession(permission: .allowed)
        let model = AudioCaptureModel(
            session: session,
            store: PendingAudioStore(baseDirectory: root),
            automaticMetering: false
        )

        await model.startRecording()
        session.time = 0.7
        model.stopRecording()

        XCTAssertEqual(model.elapsedTime, 0.7, accuracy: 0.001)
        XCTAssertEqual(model.phase, .captured)
    }

    func testTenMinuteSafetyLimitStopsAndRetainsRecording() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = FakeAudioRecordingSession(permission: .allowed)
        let model = AudioCaptureModel(
            session: session,
            store: PendingAudioStore(baseDirectory: root),
            automaticMetering: false
        )

        await model.startRecording()
        let recordingURL = try XCTUnwrap(model.capturedURL)
        session.time = AudioCaptureModel.maximumRecordingDuration
        model.refreshMeter()

        guard case .interrupted = model.phase else {
            return XCTFail("Expected the safety limit to stop capture")
        }
        XCTAssertFalse(session.isRecording)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path))
    }

    func testMultipleRecoveredRecordingsAreSurfacedOldestFirst() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PendingAudioStore(baseDirectory: root)
        let older = try store.makeRecordingURL(at: Date(timeIntervalSince1970: 1_000))
        let newer = try store.makeRecordingURL(at: Date(timeIntervalSince1970: 2_000))
        try Data("older".utf8).write(to: older)
        try Data("newer".utf8).write(to: newer)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2_000)], ofItemAtPath: newer.path)

        let model = AudioCaptureModel(
            session: FakeAudioRecordingSession(permission: .allowed),
            store: store,
            automaticMetering: false
        )

        XCTAssertEqual(model.capturedURL?.standardizedFileURL, older.standardizedFileURL)
        model.discardRecording()
        XCTAssertEqual(model.capturedURL?.standardizedFileURL, newer.standardizedFileURL)
    }

    private func makeTemporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DiaryCaptureTests-\(UUID().uuidString)", isDirectory: true)
    }
}

@MainActor
private final class FakeAudioRecordingSession: AudioRecordingSession {
    let permission: MicrophonePermission
    var reading = AudioMeterReading.silence
    var time: TimeInterval = 0
    var onUnexpectedEnd: ((AudioSessionEnd) -> Void)?
    var failsWhenStarting = false
    private(set) var startedURL: URL?
    private(set) var isRecording = false

    init(permission: MicrophonePermission) {
        self.permission = permission
    }

    var currentTime: TimeInterval { time }

    func requestPermission() async -> MicrophonePermission {
        permission
    }

    func startRecording(to url: URL) throws {
        startedURL = url
        try Data("audio".utf8).write(to: url)
        if failsWhenStarting {
            throw AudioRecordingError.couldNotStart
        }
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }

    func meterReading() -> AudioMeterReading {
        reading
    }
}
