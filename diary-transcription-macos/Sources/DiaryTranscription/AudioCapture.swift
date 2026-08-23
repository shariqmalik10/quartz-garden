import AVFoundation
import DiaryCore
import Foundation
import Observation

enum MicrophonePermission: Equatable {
    case undetermined
    case allowed
    case denied
}

enum AudioSessionEnd: Equatable {
    case completed
    case failed(String)
}

@MainActor
protocol AudioRecordingSession: AnyObject {
    var currentTime: TimeInterval { get }
    var onUnexpectedEnd: ((AudioSessionEnd) -> Void)? { get set }
    func requestPermission() async -> MicrophonePermission
    func startRecording(to url: URL) throws
    func stopRecording()
    func meterReading() -> AudioMeterReading
}

enum AudioRecordingError: LocalizedError, Equatable {
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            "The microphone recording could not start. Check the selected input in System Settings."
        }
    }
}

@MainActor
final class SystemAudioRecordingSession: NSObject, AudioRecordingSession, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var stopWasRequested = false
    var onUnexpectedEnd: ((AudioSessionEnd) -> Void)?

    var currentTime: TimeInterval {
        recorder?.currentTime ?? 0
    }

    func requestPermission() async -> MicrophonePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .allowed
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let allowed = await AVCaptureDevice.requestAccess(for: .audio)
            return allowed ? .allowed : .denied
        @unknown default:
            return .denied
        }
    }

    func startRecording(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        stopWasRequested = false
        guard recorder.prepareToRecord(), recorder.record() else {
            throw AudioRecordingError.couldNotStart
        }
        self.recorder = recorder
    }

    func stopRecording() {
        stopWasRequested = true
        recorder?.stop()
    }

    func meterReading() -> AudioMeterReading {
        guard let recorder, recorder.isRecording else { return .silence }
        recorder.updateMeters()
        return AudioMeterReading(
            averagePower: recorder.averagePower(forChannel: 0),
            peakPower: recorder.peakPower(forChannel: 0)
        )
    }

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.stopWasRequested {
                self.stopWasRequested = false
                return
            }
            self.onUnexpectedEnd?(flag
                ? .completed
                : .failed("Recording ended before it could be finalized."))
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: (any Error)?
    ) {
        let message = error?.localizedDescription ?? "The recording could not be encoded."
        Task { @MainActor [weak self] in
            self?.onUnexpectedEnd?(.failed(message))
        }
    }
}

struct PendingAudioStore {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        let base = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.directoryURL = base
            .appendingPathComponent("DiaryTranscription", isDirectory: true)
            .appendingPathComponent("Pending Audio", isDirectory: true)
    }

    func makeRecordingURL(at date: Date = Date()) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "diary-\(formatter.string(from: date))-\(UUID().uuidString.prefix(8)).m4a"
        return directoryURL.appendingPathComponent(name)
    }

    func latestRecordingURL() throws -> URL? {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return nil }
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "m4a" }
        return try urls.max { lhs, rhs in
            let left = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let right = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return left < right
        }
    }

    func isReadableRecording(_ url: URL) -> Bool {
        (try? AVAudioFile(forReading: url)) != nil
    }

    func discard(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == directoryURL.standardizedFileURL else {
            return
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

@MainActor
@Observable
final class AudioCaptureModel {
    enum Phase: Equatable {
        case idle
        case requestingPermission
        case recording
        case captured
        case interrupted(String)
        case permissionDenied
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var samples: [Double] = []
    private(set) var inputLevel = 0.0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var capturedURL: URL?

    private let session: any AudioRecordingSession
    private let store: PendingAudioStore
    private let automaticMetering: Bool
    private var waveform = WaveformBuffer(capacity: 31)
    private var meterTask: Task<Void, Never>?

    init(
        session: any AudioRecordingSession = SystemAudioRecordingSession(),
        store: PendingAudioStore = PendingAudioStore(),
        automaticMetering: Bool = true
    ) {
        self.session = session
        self.store = store
        self.automaticMetering = automaticMetering
        if let pending = try? store.latestRecordingURL() {
            capturedURL = pending
            phase = store.isReadableRecording(pending)
                ? .captured
                : .interrupted("The pending audio could not be verified. You can inspect or discard the file.")
        }
        session.onUnexpectedEnd = { [weak self] event in
            self?.handleUnexpectedEnd(event)
        }
    }

    var isRecording: Bool {
        phase == .recording
    }

    var formattedDuration: String {
        let seconds = max(0, Int(elapsedTime.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func primaryAction() async {
        if isRecording {
            stopRecording()
        } else if phase == .idle || isFailurePhase {
            await startRecording()
        }
    }

    func startRecording() async {
        guard phase == .idle || isFailurePhase else { return }
        phase = .requestingPermission

        guard await session.requestPermission() == .allowed else {
            phase = .permissionDenied
            return
        }

        do {
            let url = try store.makeRecordingURL()
            waveform.reset()
            samples = []
            inputLevel = 0
            elapsedTime = 0
            capturedURL = url
            try session.startRecording(to: url)
            phase = .recording
            if automaticMetering {
                beginMetering()
            }
        } catch {
            if let capturedURL {
                try? store.discard(capturedURL)
            }
            capturedURL = nil
            phase = .failed(error.localizedDescription)
        }
    }

    func stopRecording() {
        guard phase == .recording else { return }
        refreshMeter()
        meterTask?.cancel()
        meterTask = nil
        session.stopRecording()
        inputLevel = 0
        phase = .captured
    }

    func discardRecording() {
        guard isRetainedRecording, let capturedURL else { return }
        do {
            try store.discard(capturedURL)
            reset()
        } catch {
            phase = .interrupted("The recording is still on disk, but it could not be discarded: \(error.localizedDescription)")
        }
    }

    func resetPermissionState() {
        guard phase == .permissionDenied else { return }
        phase = .idle
    }

    func refreshMeter() {
        guard phase == .recording else { return }
        let reading = session.meterReading()
        let average = AudioLevelMeter.normalizedLevel(decibels: reading.averagePower)
        let peak = AudioLevelMeter.normalizedLevel(decibels: reading.peakPower)
        inputLevel = min(1, average * 0.72 + peak * 0.28)
        waveform.append(inputLevel)
        samples = waveform.samples
        let currentTime = session.currentTime
        if Int(currentTime) != Int(elapsedTime) {
            elapsedTime = currentTime
        }
    }

    private var isFailurePhase: Bool {
        if case .failed = phase, capturedURL == nil { return true }
        return false
    }

    private var isRetainedRecording: Bool {
        switch phase {
        case .captured, .interrupted:
            true
        default:
            false
        }
    }

    private func handleUnexpectedEnd(_ event: AudioSessionEnd) {
        guard phase == .recording else { return }
        meterTask?.cancel()
        meterTask = nil
        inputLevel = 0
        switch event {
        case .completed:
            phase = .captured
        case let .failed(message):
            phase = .interrupted(message)
        }
    }

    private func beginMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                self.refreshMeter()
            }
        }
    }

    private func reset() {
        meterTask?.cancel()
        meterTask = nil
        waveform.reset()
        samples = []
        inputLevel = 0
        elapsedTime = 0
        capturedURL = nil
        phase = .idle
    }
}
