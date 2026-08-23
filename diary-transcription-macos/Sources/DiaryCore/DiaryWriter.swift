import Foundation

/// Serializes all writes made by this process. Each disk mutation is also wrapped in
/// `NSFileCoordinator` so cooperative editors and sync providers see an append as one write.
public actor DiaryWriter {
    private let fileManager: FileManager
    private let formatting: DiaryDateFormatting
    private var vaultURL: URL?

    public init(
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) {
        self.formatting = DiaryDateFormatting(calendar: calendar)
        self.fileManager = fileManager
    }

    @discardableResult
    public func configureVault(_ url: URL) throws -> URL {
        let normalizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: normalizedURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DiaryError.invalidVault(normalizedURL)
        }

        let diaryDirectory = normalizedURL.appendingPathComponent("Diary", isDirectory: true)
        try fileManager.createDirectory(
            at: diaryDirectory,
            withIntermediateDirectories: true
        )
        vaultURL = normalizedURL
        return diaryDirectory
    }

    public func clearVault() {
        vaultURL = nil
    }

    public func configuredVaultURL() -> URL? {
        vaultURL
    }

    /// Appends one Markdown section and returns the daily file URL.
    /// The daily file is absent until this method has a non-empty entry to persist.
    @discardableResult
    public func append(_ text: String, at date: Date = Date()) throws -> URL {
        guard let vaultURL else {
            throw DiaryError.vaultNotConfigured
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DiaryError.emptyEntry
        }

        // Revalidate on every write in case the vault was moved or unmounted.
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: vaultURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DiaryError.invalidVault(vaultURL)
        }

        let diaryDirectory = vaultURL.appendingPathComponent("Diary", isDirectory: true)
        try fileManager.createDirectory(at: diaryDirectory, withIntermediateDirectories: true)
        let fileURL = diaryDirectory.appendingPathComponent(formatting.fileName(for: date))
        let normalizedText = text.trimmingCharacters(in: .newlines)
        let day = formatting.dateString(for: date)
        let time = formatting.timeString(for: date)

        try coordinateWrite(at: fileURL) { coordinatedURL in
            if self.fileManager.fileExists(atPath: coordinatedURL.path) {
                try self.appendToExistingFile(
                    at: coordinatedURL,
                    entryText: normalizedText,
                    time: time,
                    day: day
                )
            } else {
                try self.createFirstEntryAtomically(
                    at: coordinatedURL,
                    entryText: normalizedText,
                    time: time,
                    day: day
                )
            }
        }
        return fileURL
    }

    private func coordinateWrite(at fileURL: URL, operation: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?

        coordinator.coordinate(
            writingItemAt: fileURL,
            options: .forMerging,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try operation(coordinatedURL)
            } catch {
                operationError = error
            }
        }

        if let coordinationError {
            throw DiaryError.fileCoordinationFailed(coordinationError.localizedDescription)
        }
        if let operationError {
            throw operationError
        }
    }

    private func createFirstEntryAtomically(
        at fileURL: URL,
        entryText: String,
        time: String,
        day: String
    ) throws {
        let contents = "# Diary Log — \(day)\n\n## \(time)\n\(entryText)\n"
        let data = Data(contents.utf8)
        // Stage a complete sibling file, then move it into the previously absent target.
        // `moveItem` refuses to replace a file that appeared in the meantime.
        let stagedURL = fileURL.deletingLastPathComponent().appendingPathComponent(
            ".diary-write-\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: stagedURL) }
        try data.write(to: stagedURL, options: .atomic)
        try fileManager.moveItem(at: stagedURL, to: fileURL)
    }

    private func appendToExistingFile(
        at fileURL: URL,
        entryText: String,
        time: String,
        day: String
    ) throws {
        let handle = try FileHandle(forUpdating: fileURL)
        defer { try? handle.close() }

        let size = try handle.seekToEnd()
        if size == 0 {
            let contents = "# Diary Log — \(day)\n\n## \(time)\n\(entryText)\n"
            try handle.write(contentsOf: Data(contents.utf8))
            try handle.synchronize()
            return
        }

        let tailLength = min(size, 2)
        try handle.seek(toOffset: size - tailLength)
        let tail = try handle.read(upToCount: Int(tailLength)) ?? Data()
        try handle.seekToEnd()

        let separator: String
        if tail.suffix(2) == Data("\n\n".utf8) {
            separator = ""
        } else if tail.last == Character("\n").asciiValue {
            separator = "\n"
        } else {
            separator = "\n\n"
        }

        let entry = "\(separator)## \(time)\n\(entryText)\n"
        try handle.write(contentsOf: Data(entry.utf8))
        try handle.synchronize()
    }
}

private extension Character {
    var asciiValue: UInt8? {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1, scalar.isASCII else {
            return nil
        }
        return UInt8(scalar.value)
    }
}
