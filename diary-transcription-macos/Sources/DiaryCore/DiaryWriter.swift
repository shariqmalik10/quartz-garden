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
      isDirectory.boolValue
    else {
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

  public func diaryFileURL(at date: Date = Date()) throws -> URL {
    guard let vaultURL else {
      throw DiaryError.vaultNotConfigured
    }
    return
      vaultURL
      .appendingPathComponent("Diary", isDirectory: true)
      .appendingPathComponent(formatting.fileName(for: date))
  }

  public func fileURL(for relativePath: String) throws -> URL {
    guard let vaultURL else {
      throw DiaryError.vaultNotConfigured
    }
    return try validatedMarkdownURL(
      vaultURL.appendingPathComponent(relativePath),
      mustExist: false
    )
  }

  public func relativePath(for fileURL: URL) throws -> String {
    let validatedURL = try validatedMarkdownURL(fileURL, mustExist: true)
    guard let vaultURL else {
      throw DiaryError.vaultNotConfigured
    }
    let rootPath = vaultURL.resolvingSymlinksInPath().standardizedFileURL.path
    return String(validatedURL.path.dropFirst(rootPath.count + 1))
  }

  /// Appends one Markdown section and returns the daily file URL.
  /// The daily file is absent until this method has a non-empty entry to persist.
  @discardableResult
  public func append(
    _ text: String,
    at date: Date = Date(),
    idempotencyKey: String? = nil
  ) throws -> URL {
    guard let vaultURL else {
      throw DiaryError.vaultNotConfigured
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DiaryError.emptyEntry
    }

    // Revalidate on every write in case the vault was moved or unmounted.
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: vaultURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw DiaryError.invalidVault(vaultURL)
    }

    let diaryDirectory = vaultURL.appendingPathComponent("Diary", isDirectory: true)
    try fileManager.createDirectory(at: diaryDirectory, withIntermediateDirectories: true)
    let fileURL = diaryDirectory.appendingPathComponent(formatting.fileName(for: date))
    let normalizedText = text.trimmingCharacters(in: .newlines)
    let day = formatting.dateString(for: date)
    let time = formatting.timeString(for: date)
    let marker = idempotencyKey.map { "<!-- diary-transcription:\($0) -->" }

    try coordinateWrite(at: fileURL) { coordinatedURL in
      if self.fileManager.fileExists(atPath: coordinatedURL.path) {
        if let marker,
          let existing = try? String(contentsOf: coordinatedURL, encoding: .utf8),
          existing.contains(marker)
        {
          return
        }
        try self.appendToExistingFile(
          at: coordinatedURL,
          entryText: normalizedText,
          time: time,
          day: day,
          marker: marker
        )
      } else {
        try self.createFirstEntryAtomically(
          at: coordinatedURL,
          entryText: normalizedText,
          time: time,
          day: day,
          marker: marker
        )
      }
    }
    return fileURL
  }

  /// Appends a paragraph to an existing Markdown file inside the configured vault.
  /// This is intentionally separate from the timestamped daily log format so a
  /// continued essay or study note reads naturally in Obsidian.
  @discardableResult
  public func appendToMarkdownFile(
    _ text: String,
    relativePath: String,
    idempotencyKey: String? = nil
  ) throws -> URL {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DiaryError.emptyEntry
    }
    let fileURL = try fileURL(for: relativePath)
    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw DiaryError.entryFileMissing(fileURL)
    }
    let normalizedText = text.trimmingCharacters(in: .newlines)
    let marker = idempotencyKey.map { "<!-- diary-transcription:\($0) -->" }

    try coordinateWrite(at: fileURL) { coordinatedURL in
      if let marker,
        let existing = try? String(contentsOf: coordinatedURL, encoding: .utf8),
        existing.contains(marker)
      {
        return
      }
      try self.appendParagraph(
        at: coordinatedURL,
        text: normalizedText,
        marker: marker
      )
    }
    return fileURL
  }

  /// Creates a private Quartz-ready draft and returns its vault-relative URL.
  /// Publication remains an explicit metadata change by the user.
  @discardableResult
  public func createWritingDraft(
    at requestedURL: URL,
    title: String? = nil,
    date: Date = Date()
  ) throws -> URL {
    guard let vaultURL else {
      throw DiaryError.vaultNotConfigured
    }
    let normalizedURL =
      requestedURL.pathExtension.lowercased() == "md"
      ? requestedURL
      : requestedURL.appendingPathExtension("md")
    let fileURL = try validatedMarkdownURL(normalizedURL, mustExist: false)
    let relativePath = try relativePathForPotentialFile(fileURL, vaultURL: vaultURL)
    guard relativePath == "Writing" || relativePath.hasPrefix("Writing/") else {
      throw DiaryError.invalidWritingDestination(fileURL)
    }
    guard !fileManager.fileExists(atPath: fileURL.path) else {
      throw DiaryError.entryFileAlreadyExists(fileURL)
    }

    try fileManager.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let fallbackTitle = fileURL.deletingPathExtension().lastPathComponent
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
    let cleanTitle = (title ?? fallbackTitle)
      .split(whereSeparator: { $0.isNewline })
      .joined(separator: " ")
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let day = formatting.dateString(for: date)
    let contents = """
      ---
      title: "\(cleanTitle)"
      date: \(day)
      kind: writing
      visibility: private
      draft: true
      tags: []
      ---

      """
    try Data(contents.utf8).write(to: fileURL, options: .withoutOverwriting)
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
    day: String,
    marker: String?
  ) throws {
    let markerLine = marker.map { "\($0)\n" } ?? ""
    let contents = "# Diary Log — \(day)\n\n## \(time)\n\(markerLine)\(entryText)\n"
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
    day: String,
    marker: String?
  ) throws {
    let handle = try FileHandle(forUpdating: fileURL)
    defer { try? handle.close() }

    let size = try handle.seekToEnd()
    if size == 0 {
      let markerLine = marker.map { "\($0)\n" } ?? ""
      let contents = "# Diary Log — \(day)\n\n## \(time)\n\(markerLine)\(entryText)\n"
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

    let markerLine = marker.map { "\($0)\n" } ?? ""
    let entry = "\(separator)## \(time)\n\(markerLine)\(entryText)\n"
    try handle.write(contentsOf: Data(entry.utf8))
    try handle.synchronize()
  }

  private func appendParagraph(
    at fileURL: URL,
    text: String,
    marker: String?
  ) throws {
    let handle = try FileHandle(forUpdating: fileURL)
    defer { try? handle.close() }

    let size = try handle.seekToEnd()
    var separator = ""
    if size > 0 {
      let tailLength = min(size, 2)
      try handle.seek(toOffset: size - tailLength)
      let tail = try handle.read(upToCount: Int(tailLength)) ?? Data()
      try handle.seekToEnd()
      if tail.suffix(2) == Data("\n\n".utf8) {
        separator = ""
      } else if tail.last == Character("\n").asciiValue {
        separator = "\n"
      } else {
        separator = "\n\n"
      }
    }

    let markerLine = marker.map { "\($0)\n" } ?? ""
    try handle.write(contentsOf: Data("\(separator)\(markerLine)\(text)\n".utf8))
    try handle.synchronize()
  }

  private func validatedMarkdownURL(_ requestedURL: URL, mustExist: Bool) throws -> URL {
    guard let vaultURL else {
      throw DiaryError.vaultNotConfigured
    }
    guard requestedURL.pathExtension.lowercased() == "md" else {
      throw DiaryError.invalidEntryFile(requestedURL)
    }

    let rootURL = vaultURL.resolvingSymlinksInPath().standardizedFileURL
    let candidateURL: URL
    if fileManager.fileExists(atPath: requestedURL.path) {
      candidateURL = requestedURL.resolvingSymlinksInPath().standardizedFileURL
    } else {
      let parent = requestedURL.deletingLastPathComponent()
        .resolvingSymlinksInPath()
        .standardizedFileURL
      candidateURL =
        parent.appendingPathComponent(requestedURL.lastPathComponent)
        .standardizedFileURL
    }
    guard isInside(rootURL, candidateURL) else {
      throw DiaryError.invalidEntryFile(candidateURL)
    }
    if mustExist, !fileManager.fileExists(atPath: candidateURL.path) {
      throw DiaryError.entryFileMissing(candidateURL)
    }
    return candidateURL
  }

  private func relativePathForPotentialFile(_ fileURL: URL, vaultURL: URL) throws -> String {
    let rootPath = vaultURL.resolvingSymlinksInPath().standardizedFileURL.path
    guard isInside(URL(fileURLWithPath: rootPath), fileURL) else {
      throw DiaryError.invalidEntryFile(fileURL)
    }
    return String(fileURL.path.dropFirst(rootPath.count + 1))
  }

  private func isInside(_ parent: URL, _ child: URL) -> Bool {
    let parentPath = parent.standardizedFileURL.path
    let childPath = child.standardizedFileURL.path
    return childPath.hasPrefix(parentPath + "/")
  }
}

extension Character {
  fileprivate var asciiValue: UInt8? {
    guard let scalar = unicodeScalars.first, unicodeScalars.count == 1, scalar.isASCII else {
      return nil
    }
    return UInt8(scalar.value)
  }
}
