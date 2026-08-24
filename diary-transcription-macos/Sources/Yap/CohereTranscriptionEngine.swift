import Foundation
import HuggingFace
import MLXAudioCore
import MLXAudioSTT

protocol LocalTranscriptionEngine: Sendable {
    nonisolated var isInstalled: Bool { get }
    nonisolated var modelDirectory: URL { get }
    func install(progress: @MainActor @escaping @Sendable (Double) -> Void) async throws
    func prepareOffline() async throws
    func transcribe(audioURL: URL, language: String) async throws -> String
    func removeInstalledModel() async throws
}

enum CohereEngineError: LocalizedError {
    case modelNotInstalled
    case emptyTranscript
    case unsupportedLanguage

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            "The local transcription model is not installed. Open Settings to install it."
        case .emptyTranscript:
            "No speech was recognized. The audio is still saved locally, so you can retry or discard it."
        case .unsupportedLanguage:
            "That transcription language is not supported by the installed local model. Choose another language in Settings."
        }
    }
}

actor CohereTranscriptionEngine: LocalTranscriptionEngine {
    static let repository = "beshkenadze/cohere-transcribe-03-2026-mlx-8bit"
    static let revision = "d1f843476f84846e6fe7aa58a6033f17882f0ec9"

    nonisolated let modelDirectory: URL
    private let cacheRoot: URL
    private var model: CohereTranscribeModel?

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        let applicationSupport = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        cacheRoot = applicationSupport
            .appendingPathComponent("DiaryTranscription", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        modelDirectory = cacheRoot
            .appendingPathComponent(
                "models--beshkenadze--cohere-transcribe-03-2026-mlx-8bit",
                isDirectory: true
            )
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent(Self.revision, isDirectory: true)
    }

    nonisolated var isInstalled: Bool {
        Self.isCompleteModel(at: modelDirectory)
    }

    func install(progress: @MainActor @escaping @Sendable (Double) -> Void) async throws {
        try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        let snapshot = try await download(localFilesOnly: false, progress: progress)
        guard Self.isCompleteModel(at: snapshot) else {
            throw CohereEngineError.modelNotInstalled
        }
        model = try CohereTranscribeModel.fromDirectory(snapshot)
    }

    func prepareOffline() async throws {
        guard model == nil else { return }
        guard isInstalled else { throw CohereEngineError.modelNotInstalled }
        let snapshot = try await download(localFilesOnly: true) { _ in }
        model = try CohereTranscribeModel.fromDirectory(snapshot)
    }

    func transcribe(audioURL: URL, language: String) async throws -> String {
        let supportedLanguages: Set<String> = [
            "en", "fr", "de", "es", "it", "pt", "nl", "pl", "el", "ar", "ja", "zh", "vi", "ko"
        ]
        guard supportedLanguages.contains(language) else {
            throw CohereEngineError.unsupportedLanguage
        }
        try await prepareOffline()
        guard let model else { throw CohereEngineError.modelNotInstalled }
        let (_, audio) = try loadAudioArray(from: audioURL, sampleRate: 16_000)
        let output = model.generate(
            audio: audio,
            generationParameters: STTGenerateParameters(
                language: language,
                chunkDuration: 30,
                minChunkDuration: 0.5
            )
        )
        let text = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CohereEngineError.emptyTranscript }
        return text
    }

    func removeInstalledModel() async throws {
        model = nil
        guard FileManager.default.fileExists(atPath: cacheRoot.path) else { return }
        try FileManager.default.removeItem(at: cacheRoot)
    }

    private func download(
        localFilesOnly: Bool,
        progress: @MainActor @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard let repository = Repo.ID(rawValue: Self.repository) else {
            throw CohereEngineError.modelNotInstalled
        }
        let cache = HubCache(cacheDirectory: cacheRoot)
        let client = HubClient(cache: cache)
        return try await client.downloadSnapshot(
            of: repository,
            kind: .model,
            revision: Self.revision,
            matching: ["*.safetensors", "*.json", "*.model"],
            localFilesOnly: localFilesOnly,
            maxConcurrentDownloads: 4
        ) { value in
            progress(value.fractionCompleted)
        }
    }

    private nonisolated static func isCompleteModel(at directory: URL) -> Bool {
        let fileManager = FileManager.default
        let required = ["config.json", "tokenizer.model", "tokenizer_config.json"]
        guard required.allSatisfy({ name in
            let url = directory.appendingPathComponent(name)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return fileManager.fileExists(atPath: url.path) && size > 0
        }) else { return false }
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.contains { url in
            guard url.pathExtension == "safetensors" else { return false }
            return ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0
        }
    }
}
