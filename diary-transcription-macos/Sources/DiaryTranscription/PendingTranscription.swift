import Foundation

enum PendingTranscriptionStoreError: LocalizedError {
    case mismatchedAudioPath

    var errorDescription: String? {
        "The recovered transcription metadata did not match its audio file. The metadata was quarantined and the audio was kept."
    }
}

struct PendingTranscription: Codable, Equatable, Sendable {
    let entryID: String
    let audioPath: String
    let capturedAt: Date
    var transcript: String?
    var savedFilePath: String?

    var audioURL: URL { URL(fileURLWithPath: audioPath) }

    init(
        entryID: String = UUID().uuidString,
        audioPath: String,
        capturedAt: Date,
        transcript: String?,
        savedFilePath: String? = nil
    ) {
        self.entryID = entryID
        self.audioPath = audioPath
        self.capturedAt = capturedAt
        self.transcript = transcript
        self.savedFilePath = savedFilePath
    }
}

struct PendingTranscriptionStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(for audioURL: URL) throws -> PendingTranscription? {
        let url = sidecarURL(for: audioURL)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let pending = try JSONDecoder().decode(PendingTranscription.self, from: Data(contentsOf: url))
            guard pending.audioURL.standardizedFileURL == audioURL.standardizedFileURL else {
                throw PendingTranscriptionStoreError.mismatchedAudioPath
            }
            return pending
        } catch {
            let quarantineURL = url
                .deletingPathExtension()
                .appendingPathExtension("invalid-\(UUID().uuidString).json")
            try fileManager.moveItem(at: url, to: quarantineURL)
            return nil
        }
    }

    func save(_ pending: PendingTranscription, for audioURL: URL) throws {
        guard pending.audioURL.standardizedFileURL == audioURL.standardizedFileURL else {
            throw PendingTranscriptionStoreError.mismatchedAudioPath
        }
        let data = try JSONEncoder().encode(pending)
        try data.write(to: sidecarURL(for: audioURL), options: [.atomic])
    }

    func remove(for audioURL: URL) throws {
        let url = sidecarURL(for: audioURL)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func sidecarURL(for audioURL: URL) -> URL {
        audioURL.deletingPathExtension().appendingPathExtension("pending.json")
    }
}
