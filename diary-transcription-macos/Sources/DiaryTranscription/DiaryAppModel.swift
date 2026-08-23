import AppKit
import DiaryCore
import Foundation
import Observation
import UniformTypeIdentifiers

enum EntryWorkspace: String, CaseIterable, Codable, Identifiable, Sendable {
  case diary
  case blog
  case notes
  case anyMarkdown

  var id: String { rawValue }

  var title: String {
    switch self {
    case .diary: "Diary"
    case .blog: "Blog"
    case .notes: "Notes"
    case .anyMarkdown: "Any file"
    }
  }

  var detail: String {
    switch self {
    case .diary: "Private daily logs"
    case .blog: "Quartz-ready drafts"
    case .notes: "Study and working notes"
    case .anyMarkdown: "Anywhere in your vault"
    }
  }

  var symbolName: String {
    switch self {
    case .diary: "calendar"
    case .blog: "text.book.closed"
    case .notes: "note.text"
    case .anyMarkdown: "doc.text.magnifyingglass"
    }
  }

  var directoryRelativePath: String {
    switch self {
    case .diary: "Diary"
    case .blog: "Writing/Blogs"
    case .notes: "Notes"
    case .anyMarkdown: ""
    }
  }

  func accepts(relativePath: String) -> Bool {
    switch self {
    case .diary:
      relativePath.hasPrefix("Diary/")
    case .blog:
      // Continue older Writing/ drafts while placing every new blog in Writing/Blogs/.
      relativePath.hasPrefix("Writing/")
    case .notes:
      relativePath.hasPrefix("Notes/")
    case .anyMarkdown:
      true
    }
  }
}

@MainActor
@Observable
final class DiaryAppModel {
  enum Status: Equatable {
    case ready(String)
    case saved(String)
    case error(String)

    var title: String {
      switch self {
      case .ready: "Ready"
      case .saved: "Saved"
      case .error: "Needs attention"
      }
    }

    var detail: String {
      switch self {
      case .ready(let detail), .saved(let detail), .error(let detail): detail
      }
    }

    var symbolName: String {
      switch self {
      case .ready: "checkmark.circle"
      case .saved: "checkmark.circle.fill"
      case .error: "exclamationmark.triangle.fill"
      }
    }
  }

  enum ModelState: Equatable {
    case notInstalled
    case downloading(Double)
    case installed
    case loading
    case ready
    case failed(String)

    var isUsable: Bool {
      switch self {
      case .installed, .ready: true
      default: false
      }
    }
  }

  enum WorkflowState: Equatable {
    case idle
    case transcribing
    case saving
    case saved(fileName: String, preview: String)
    case failed(String)

    var isBusy: Bool {
      switch self {
      case .transcribing, .saving: true
      default: false
      }
    }
  }

  enum EntryDestination: Equatable, Sendable {
    case todayDiary
    case existing(relativePath: String)

    var relativePath: String? {
      if case .existing(let relativePath) = self { return relativePath }
      return nil
    }
  }

  struct Language: Identifiable, Hashable {
    let id: String
    let name: String
  }

  struct RecentDestination: Identifiable, Equatable, Sendable {
    let relativePath: String
    let workspace: EntryWorkspace

    var id: String { relativePath }
    var title: String {
      URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
    }
    var folder: String {
      URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
    }
  }

  static let languages: [Language] = [
    .init(id: "en", name: "English"),
    .init(id: "ar", name: "Arabic"),
    .init(id: "de", name: "German"),
    .init(id: "el", name: "Greek"),
    .init(id: "es", name: "Spanish"),
    .init(id: "fr", name: "French"),
    .init(id: "it", name: "Italian"),
    .init(id: "ja", name: "Japanese"),
    .init(id: "ko", name: "Korean"),
    .init(id: "nl", name: "Dutch"),
    .init(id: "pl", name: "Polish"),
    .init(id: "pt", name: "Portuguese"),
    .init(id: "vi", name: "Vietnamese"),
    .init(id: "zh", name: "Chinese"),
  ]

  let capture: AudioCaptureModel
  var status: Status = .error("Choose an Obsidian vault to begin.")
  var workflowState: WorkflowState = .idle
  var modelState: ModelState
  var testEntry = ""
  var vaultPath: String?
  var isSaving = false
  var shortcut: GlobalKeyBinding?
  var shortcutError: String?
  var entryDestination: EntryDestination {
    didSet {
      if let relativePath = entryDestination.relativePath {
        defaults.set(relativePath, forKey: Keys.destination)
      } else {
        defaults.removeObject(forKey: Keys.destination)
      }
    }
  }
  var selectedWorkspace: EntryWorkspace {
    didSet { defaults.set(selectedWorkspace.rawValue, forKey: Keys.workspace) }
  }
  var themeChoice: DiaryThemeChoice {
    didSet { defaults.set(themeChoice.rawValue, forKey: Keys.theme) }
  }
  var visualizationStyle: CaptureVisualizationStyle {
    didSet { defaults.set(visualizationStyle.rawValue, forKey: Keys.visualization) }
  }
  var usageStats: DiaryUsageStats
  var lastSavedFilePath: String?
  var languageCode: String {
    didSet { defaults.set(languageCode, forKey: Keys.language) }
  }
  private(set) var recentDestinationPaths: [String] {
    didSet { defaults.set(recentDestinationPaths, forKey: Keys.recentDestinations) }
  }

  private let writer: DiaryWriter
  private let bookmarks: SecurityScopedBookmarkStore
  private let transcriber: any LocalTranscriptionEngine
  private let pendingStore: PendingTranscriptionStore
  private let defaults: UserDefaults
  private let statsStore: DiaryUsageStatsStore
  private let shortcutController: GlobalShortcutController
  private var vaultAccess: VaultAccess?
  private var modelWarmup: Task<Void, Error>?

  init(
    writer: DiaryWriter = DiaryWriter(),
    bookmarks: SecurityScopedBookmarkStore = SecurityScopedBookmarkStore(),
    capture: AudioCaptureModel = AudioCaptureModel(),
    transcriber: any LocalTranscriptionEngine = CohereTranscriptionEngine(),
    pendingStore: PendingTranscriptionStore = PendingTranscriptionStore(),
    defaults: UserDefaults = .standard,
    shortcutController: GlobalShortcutController = GlobalShortcutController()
  ) {
    self.writer = writer
    self.bookmarks = bookmarks
    self.capture = capture
    self.transcriber = transcriber
    self.pendingStore = pendingStore
    self.defaults = defaults
    statsStore = DiaryUsageStatsStore(defaults: defaults)
    self.shortcutController = shortcutController
    modelState = transcriber.isInstalled ? .installed : .notInstalled
    let storedDestination = defaults.string(forKey: Keys.destination)
    entryDestination = storedDestination.map { .existing(relativePath: $0) } ?? .todayDiary
    selectedWorkspace =
      defaults.string(forKey: Keys.workspace)
      .flatMap(EntryWorkspace.init(rawValue:))
      ?? storedDestination.map(Self.workspace(forRelativePath:))
      ?? .diary
    themeChoice =
      defaults.string(forKey: Keys.theme)
      .flatMap(DiaryThemeChoice.init(rawValue:)) ?? .ink
    visualizationStyle =
      defaults.string(forKey: Keys.visualization)
      .flatMap(CaptureVisualizationStyle.init(rawValue:)) ?? .waveform
    usageStats = statsStore.load()
    lastSavedFilePath = defaults.string(forKey: Keys.lastSavedFile)
    var initialRecentDestinations =
      defaults.stringArray(forKey: Keys.recentDestinations) ?? []
    if let storedDestination, !initialRecentDestinations.contains(storedDestination) {
      initialRecentDestinations.insert(storedDestination, at: 0)
    }
    recentDestinationPaths = initialRecentDestinations
    let storedLanguage = defaults.string(forKey: Keys.language) ?? "en"
    languageCode =
      Self.languages.contains(where: { $0.id == storedLanguage })
      ? storedLanguage
      : "en"
    defaults.set(languageCode, forKey: Keys.language)
    if let data = defaults.data(forKey: Keys.shortcut) {
      shortcut = try? JSONDecoder().decode(GlobalKeyBinding.self, from: data)
    }
    if capture.capturedURL != nil {
      workflowState = .failed(
        "A recording from an earlier session is safe on this Mac. Retry it or discard it.")
    }
    DiaryAppDelegate.appModel = self
    Task { @MainActor [weak self] in
      await self?.restoreVault()
      self?.applyShortcutRegistration()
    }
  }

  var hasPendingRecording: Bool { capture.capturedURL != nil }
  var destinationWorkspace: EntryWorkspace {
    switch entryDestination {
    case .todayDiary:
      .diary
    case .existing(let relativePath):
      Self.workspace(forRelativePath: relativePath)
    }
  }

  var destinationTitle: String {
    switch entryDestination {
    case .todayDiary:
      "Today’s diary"
    case .existing(let relativePath):
      URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
    }
  }

  var destinationDetail: String {
    switch entryDestination {
    case .todayDiary:
      "Diary/ · today’s private log"
    case .existing(let relativePath) where destinationWorkspace == .blog:
      "\(relativePath) · blog draft"
    case .existing(let relativePath):
      relativePath
    }
  }

  func recentDestinations(for workspace: EntryWorkspace) -> [RecentDestination] {
    guard let vaultPath else { return [] }
    let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
    return recentDestinationPaths.compactMap { relativePath in
      guard workspace.accepts(relativePath: relativePath),
        FileManager.default.fileExists(
          atPath: vaultURL.appendingPathComponent(relativePath).path
        )
      else { return nil }
      return RecentDestination(
        relativePath: relativePath,
        workspace: Self.workspace(forRelativePath: relativePath)
      )
    }
  }

  var destinationExists: Bool {
    guard let vaultPath else { return false }
    switch entryDestination {
    case .todayDiary:
      return true
    case .existing(let relativePath):
      return FileManager.default.fileExists(
        atPath: URL(fileURLWithPath: vaultPath)
          .appendingPathComponent(relativePath).path
      )
    }
  }

  var canRecord: Bool {
    vaultPath != nil
      && destinationExists
      && modelState.isUsable
      && !workflowState.isBusy
      && !isSaving
      && !hasPendingRecording
  }

  func restoreVault() async {
    guard vaultPath == nil else { return }
    guard bookmarks.hasBookmark else { return }
    do {
      let access = try bookmarks.restoreAccess()
      guard let rootURL = Self.obsidianVaultRoot(containing: access.url) else {
        throw NSError(
          domain: "DiaryTranscription.Vault",
          code: 1,
          userInfo: [
            NSLocalizedDescriptionKey:
              "The saved folder is not inside an Obsidian vault. Choose the vault folder that contains .obsidian."
          ]
        )
      }
      if rootURL != access.url.standardizedFileURL {
        let repairedAccess = try bookmarks.saveAndAccess(rootURL)
        try await activate(repairedAccess)
      } else {
        try await activate(access)
      }
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func chooseVault() async {
    let panel = NSOpenPanel()
    panel.title = "Choose Obsidian Vault"
    panel.message =
      "Select the folder that contains .obsidian, or any folder inside that vault. Diary Transcription will use the vault root."
    panel.prompt = "Choose Vault"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false

    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      guard let rootURL = Self.obsidianVaultRoot(containing: url) else {
        throw NSError(
          domain: "DiaryTranscription.Vault",
          code: 2,
          userInfo: [
            NSLocalizedDescriptionKey:
              "That folder is not inside an Obsidian vault. Choose a folder whose parent tree contains .obsidian."
          ]
        )
      }
      let access = try bookmarks.saveAndAccess(rootURL)
      try await activate(access)
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func useTodayDiary() {
    guard !capture.isRecording, !workflowState.isBusy else { return }
    selectedWorkspace = .diary
    entryDestination = .todayDiary
    status = .ready("New entries will append to today’s private Diary log.")
  }

  func chooseExistingEntry() async {
    await chooseExistingEntry(in: .anyMarkdown)
  }

  func chooseExistingEntry(in workspace: EntryWorkspace) async {
    guard !capture.isRecording, !workflowState.isBusy,
      let vaultPath
    else { return }
    let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
    let directoryURL = vaultURL.appendingPathComponent(
      workspace.directoryRelativePath,
      isDirectory: true
    )
    let panel = NSOpenPanel()
    panel.title =
      workspace == .anyMarkdown
      ? "Continue Any Markdown File" : "Continue a \(workspace.title) File"
    panel.message =
      "Choose an existing Markdown file. Every new capture is added at the end on a fresh line; existing text is never replaced."
    panel.prompt = "Resume Writing"
    panel.directoryURL = directoryURL
    panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let relativePath = try await writer.relativePath(for: url)
      guard workspace.accepts(relativePath: relativePath) else {
        throw NSError(
          domain: "DiaryTranscription.Workspace",
          code: 1,
          userInfo: [
            NSLocalizedDescriptionKey:
              "That file is outside \(workspace.directoryRelativePath)/. Choose Any file to resume it instead."
          ]
        )
      }
      selectExistingDestination(
        relativePath,
        workspace: workspace == .anyMarkdown
          ? Self.workspace(forRelativePath: relativePath) : workspace,
        message: "Continuing \(relativePath). New text will start at the end of the file."
      )
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func createBlogDraft() async {
    await createNewEntry(in: .blog)
  }

  func createNewEntry(in workspace: EntryWorkspace) async {
    guard !capture.isRecording, !workflowState.isBusy,
      let vaultPath
    else { return }
    if workspace == .diary {
      useTodayDiary()
      return
    }
    let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
    let directoryURL = vaultURL.appendingPathComponent(
      workspace.directoryRelativePath,
      isDirectory: true
    )
    await createNewEntry(in: workspace, directoryURL: directoryURL)
  }

  func createFolderAndEntry(in workspace: EntryWorkspace, folderName: String) async {
    guard !capture.isRecording, !workflowState.isBusy, workspace != .diary else { return }
    do {
      let folderURL = try await writer.createSubdirectory(
        named: folderName,
        under: workspace.directoryRelativePath
      )
      await createNewEntry(in: workspace, directoryURL: folderURL)
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func resumeExisting(relativePath: String) {
    guard !capture.isRecording, !workflowState.isBusy,
      let vaultPath
    else { return }
    let fileURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
      .appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      status = .error("That recent file moved or was renamed. Choose it again.")
      recentDestinationPaths.removeAll { $0 == relativePath }
      return
    }
    selectExistingDestination(
      relativePath,
      workspace: Self.workspace(forRelativePath: relativePath),
      message: "Resuming \(relativePath). New text will start at the end of the file."
    )
  }

  private func createNewEntry(in workspace: EntryWorkspace, directoryURL: URL) async {
    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    } catch {
      status = .error(error.localizedDescription)
      return
    }

    let panel = NSSavePanel()
    panel.title = workspace == .blog ? "Start a Private Blog Draft" : "Create a Markdown File"
    panel.message =
      workspace == .blog
      ? "This starts private. Publish later by changing its Obsidian frontmatter."
      : "The file stays inside your Obsidian vault and future captures append at its end."
    panel.prompt = workspace == .blog ? "Create Blog Draft" : "Create File"
    panel.directoryURL = directoryURL
    panel.nameFieldStringValue =
      switch workspace {
      case .blog: "new-blog-\(Self.todayString()).md"
      case .notes: "new-note-\(Self.todayString()).md"
      case .anyMarkdown: "new-entry-\(Self.todayString()).md"
      case .diary: "diary-log_\(Self.todayString()).md"
      }
    panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
    panel.canCreateDirectories = false

    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let fileURL =
        workspace == .blog
        ? try await writer.createWritingDraft(at: url)
        : try await writer.createMarkdownDocument(at: url)
      let relativePath = try await writer.relativePath(for: fileURL)
      lastSavedFilePath = fileURL.path
      defaults.set(fileURL.path, forKey: Keys.lastSavedFile)
      selectExistingDestination(
        relativePath,
        workspace: workspace,
        message: workspace == .blog
          ? "Private blog draft created. Speak or write to keep building it."
          : "Markdown file created. Your next entry will start below its title."
      )
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func installModel() async {
    guard !workflowState.isBusy else { return }
    if case .downloading = modelState { return }
    modelState = .downloading(0)
    do {
      try await transcriber.install { [weak self] fraction in
        self?.modelState = .downloading(min(1, max(0, fraction)))
      }
      modelState = .ready
      status =
        vaultPath == nil
        ? .error("The model is ready. Choose an Obsidian vault to finish setup.")
        : .ready("Local INT8 transcription is installed and ready offline.")
    } catch {
      modelState = .failed(error.localizedDescription)
    }
  }

  func removeModel() async {
    guard !capture.isRecording, !workflowState.isBusy else { return }
    do {
      try await transcriber.removeInstalledModel()
      modelState = .notInstalled
    } catch {
      modelState = .failed(error.localizedDescription)
    }
  }

  func handlePrimaryAction() async {
    if capture.isRecording {
      capture.stopRecording()
      await processPendingRecording()
      return
    }
    guard canRecord else {
      if vaultPath == nil {
        status = .error("Choose an Obsidian vault before recording.")
      } else if !destinationExists {
        status = .error(
          "The file you were continuing has moved. Choose it again or use today’s diary.")
      } else if !modelState.isUsable {
        workflowState = .failed(
          "Install the local transcription model in Settings before recording.")
      }
      return
    }
    workflowState = .idle
    await capture.startRecording()
    guard capture.isRecording else { return }
    modelState = .loading
    modelWarmup = Task { @MainActor [weak self, transcriber] in
      do {
        try await transcriber.prepareOffline()
        self?.modelState = .ready
      } catch {
        self?.modelState = .failed(error.localizedDescription)
        self?.modelWarmup = nil
        throw error
      }
    }
  }

  func retryPendingRecording() async {
    await processPendingRecording()
  }

  func discardPendingRecording() {
    guard let audioURL = capture.capturedURL else { return }
    capture.discardRecording()
    try? pendingStore.remove(for: audioURL)
    workflowState =
      capture.capturedURL == nil
      ? .idle
      : .failed("Another recovered recording is waiting. Retry it or discard it.")
  }

  func saveTestEntry() async {
    guard !isSaving, !workflowState.isBusy, !capture.isRecording else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      let text = testEntry
      let entryID = UUID().uuidString
      let fileURL = try await appendEntry(
        text,
        at: Date(),
        destinationRelativePath: entryDestination.relativePath,
        idempotencyKey: entryID
      )
      recordUsage(entryID: entryID, text: text, audioDuration: nil, date: Date())
      testEntry = ""
      let preview = Self.preview(text)
      markSaved(fileURL: fileURL, preview: preview)
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func openTodayDiary() async {
    do {
      let url = try await writer.diaryFileURL()
      guard FileManager.default.fileExists(atPath: url.path) else {
        status = .error("Today’s diary file does not exist yet.")
        return
      }
      try openInObsidian(url)
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func openLastSavedEntry() async {
    do {
      let url: URL
      if let lastSavedFilePath {
        url = URL(fileURLWithPath: lastSavedFilePath)
      } else if let relativePath = entryDestination.relativePath {
        url = try await writer.fileURL(for: relativePath)
      } else {
        url = try await writer.diaryFileURL()
      }
      guard FileManager.default.fileExists(atPath: url.path) else {
        status = .error("The saved entry has moved. Choose the file again to continue it.")
        return
      }
      try openInObsidian(url)
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  func setShortcut(_ value: GlobalKeyBinding?) {
    do {
      try shortcutController.register(value) { [weak self] in
        Task { @MainActor in await self?.handlePrimaryAction() }
      }
      shortcut = value
      if let value, let data = try? JSONEncoder().encode(value) {
        defaults.set(data, forKey: Keys.shortcut)
      } else {
        defaults.removeObject(forKey: Keys.shortcut)
      }
      shortcutError = nil
    } catch {
      shortcutError = error.localizedDescription
    }
  }

  private func processPendingRecording() async {
    guard let audioURL = capture.capturedURL else { return }
    guard capture.elapsedTime >= 0.5 || capture.phase != .captured else {
      workflowState = .failed(
        "That recording was too short to transcribe. It is still saved locally.")
      return
    }

    var pending: PendingTranscription
    do {
      if let saved = try pendingStore.load(for: audioURL) {
        pending = saved
      } else {
        let date =
          (try? audioURL.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? Date()
        pending = PendingTranscription(
          audioPath: audioURL.path,
          capturedAt: date,
          transcript: nil,
          audioDuration: capture.elapsedTime,
          destinationRelativePath: entryDestination.relativePath
        )
        try pendingStore.save(pending, for: audioURL)
      }

      if let savedFilePath = pending.savedFilePath {
        if let transcript = pending.transcript {
          recordUsage(
            entryID: pending.entryID,
            text: transcript,
            audioDuration: pending.audioDuration,
            date: pending.capturedAt
          )
        }
        let savedURL = URL(fileURLWithPath: savedFilePath)
        rememberSavedFile(savedURL)
        try capture.completeRecording()
        try pendingStore.remove(for: audioURL)
        let fileName = savedURL.lastPathComponent
        if capture.capturedURL != nil {
          workflowState = .failed(
            "The diary entry was already saved. Another recovered recording is waiting for you.")
          status = .saved(fileName)
          return
        }
        markSaved(
          fileURL: savedURL,
          preview: Self.preview(pending.transcript ?? "")
        )
        return
      }

      if pending.transcript == nil {
        workflowState = .transcribing
        try await prepareModelForTranscription()
        let transcript = try await transcriber.transcribe(
          audioURL: audioURL,
          language: languageCode
        )
        pending.transcript = transcript
        try pendingStore.save(pending, for: audioURL)
      }

      guard let transcript = pending.transcript else {
        throw CohereEngineError.emptyTranscript
      }
      workflowState = .saving
      let fileURL = try await appendEntry(
        transcript,
        at: pending.capturedAt,
        destinationRelativePath: pending.destinationRelativePath,
        idempotencyKey: pending.entryID
      )
      pending.savedFilePath = fileURL.path
      try pendingStore.save(pending, for: audioURL)
      recordUsage(
        entryID: pending.entryID,
        text: transcript,
        audioDuration: pending.audioDuration,
        date: pending.capturedAt
      )
      rememberSavedFile(fileURL)

      do {
        try capture.completeRecording()
        try pendingStore.remove(for: audioURL)
      } catch {
        workflowState = .failed(
          "The diary entry was saved, but its retained audio could not be cleaned up: \(error.localizedDescription)"
        )
        status = .saved(fileURL.lastPathComponent)
        return
      }
      if capture.capturedURL != nil {
        workflowState = .failed(
          "The diary entry was saved. Another recovered recording is waiting for you.")
        status = .saved(fileURL.lastPathComponent)
        return
      }
      let preview = Self.preview(transcript)
      markSaved(fileURL: fileURL, preview: preview)
    } catch {
      modelWarmup = nil
      workflowState = .failed(error.localizedDescription)
    }
  }

  private func prepareModelForTranscription() async throws {
    do {
      if let modelWarmup {
        try await modelWarmup.value
      } else {
        modelState = .loading
        try await transcriber.prepareOffline()
      }
      modelWarmup = nil
      modelState = .ready
    } catch {
      modelWarmup = nil
      modelState = .failed(error.localizedDescription)
      throw error
    }
  }

  private func appendEntry(
    _ text: String,
    at date: Date,
    destinationRelativePath: String?,
    idempotencyKey: String
  ) async throws -> URL {
    if let destinationRelativePath {
      return try await writer.appendToMarkdownFile(
        text,
        relativePath: destinationRelativePath,
        idempotencyKey: idempotencyKey
      )
    }
    return try await writer.append(
      text,
      at: date,
      idempotencyKey: idempotencyKey
    )
  }

  private func recordUsage(
    entryID: String,
    text: String,
    audioDuration: TimeInterval?,
    date: Date
  ) {
    usageStats.record(
      entryID: entryID,
      text: text,
      audioDuration: audioDuration,
      date: date
    )
    statsStore.save(usageStats)
  }

  private func markSaved(fileURL: URL, preview: String) {
    rememberSavedFile(fileURL)
    workflowState = .saved(fileName: fileURL.lastPathComponent, preview: preview)
    status = .saved(fileURL.lastPathComponent)
  }

  private func rememberSavedFile(_ fileURL: URL) {
    lastSavedFilePath = fileURL.path
    defaults.set(fileURL.path, forKey: Keys.lastSavedFile)
    guard let vaultPath else { return }
    let rootPath = URL(fileURLWithPath: vaultPath, isDirectory: true).standardizedFileURL.path
    let filePath = fileURL.standardizedFileURL.path
    guard filePath.hasPrefix(rootPath + "/") else { return }
    rememberRecentDestination(String(filePath.dropFirst(rootPath.count + 1)))
  }

  private func selectExistingDestination(
    _ relativePath: String,
    workspace: EntryWorkspace,
    message: String
  ) {
    selectedWorkspace = workspace
    entryDestination = .existing(relativePath: relativePath)
    rememberRecentDestination(relativePath)
    workflowState = .idle
    status = .ready(message)
  }

  private func rememberRecentDestination(_ relativePath: String) {
    recentDestinationPaths.removeAll { $0 == relativePath }
    recentDestinationPaths.insert(relativePath, at: 0)
    if recentDestinationPaths.count > 8 {
      recentDestinationPaths.removeLast(recentDestinationPaths.count - 8)
    }
  }

  private func openInObsidian(_ fileURL: URL) throws {
    guard let vaultPath else { throw DiaryError.vaultNotConfigured }
    let url = try ObsidianLink.openURL(
      vaultURL: URL(fileURLWithPath: vaultPath, isDirectory: true),
      fileURL: fileURL
    )
    guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
      throw NSError(
        domain: "DiaryTranscription.Obsidian",
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Obsidian is not installed or has not registered its obsidian:// link yet. Open Obsidian once, then try again."
        ]
      )
    }
    guard NSWorkspace.shared.open(url) else {
      throw NSError(
        domain: "DiaryTranscription.Obsidian",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Obsidian could not open this entry."]
      )
    }
  }

  private func activate(_ access: VaultAccess) async throws {
    _ = try await writer.configureVault(access.url)
    vaultAccess = access
    vaultPath = access.url.path
    recentDestinationPaths.removeAll { relativePath in
      !FileManager.default.fileExists(
        atPath: access.url.appendingPathComponent(relativePath).path
      )
    }
    if case .existing(let relativePath) = entryDestination {
      do {
        let destinationURL = try await writer.fileURL(for: relativePath)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
          selectedWorkspace = .diary
          entryDestination = .todayDiary
        }
      } catch {
        selectedWorkspace = .diary
        entryDestination = .todayDiary
      }
    }
    status =
      modelState.isUsable
      ? .ready("Vault, destination, and local transcription are ready.")
      : .ready("Vault is ready. Install the transcription model next.")
  }

  private func applyShortcutRegistration() {
    do {
      try shortcutController.register(shortcut) { [weak self] in
        Task { @MainActor in await self?.handlePrimaryAction() }
      }
      shortcutError = nil
    } catch {
      shortcut = nil
      defaults.removeObject(forKey: Keys.shortcut)
      shortcutError = error.localizedDescription
    }
  }

  private static func preview(_ text: String) -> String {
    let collapsed =
      text
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
    return collapsed.count > 120 ? "\(collapsed.prefix(117))…" : collapsed
  }

  private static func todayString(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func workspace(forRelativePath relativePath: String) -> EntryWorkspace {
    if relativePath.hasPrefix("Diary/") { return .diary }
    if relativePath.hasPrefix("Writing/") { return .blog }
    if relativePath.hasPrefix("Notes/") { return .notes }
    return .anyMarkdown
  }

  static func obsidianVaultRoot(containing selectedURL: URL) -> URL? {
    var cursor = selectedURL.standardizedFileURL
    let fileManager = FileManager.default
    while cursor.path != "/" {
      var isDirectory: ObjCBool = false
      let marker = cursor.appendingPathComponent(".obsidian", isDirectory: true)
      if fileManager.fileExists(atPath: marker.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      {
        return cursor
      }
      let parent = cursor.deletingLastPathComponent().standardizedFileURL
      if parent == cursor { break }
      cursor = parent
    }
    return nil
  }

  private enum Keys {
    static let shortcut = "DiaryTranscription.globalShortcut"
    static let language = "DiaryTranscription.language"
    static let destination = "DiaryTranscription.destinationRelativePath"
    static let workspace = "DiaryTranscription.destinationWorkspace"
    static let recentDestinations = "DiaryTranscription.recentDestinations"
    static let theme = "DiaryTranscription.theme"
    static let visualization = "DiaryTranscription.visualization"
    static let lastSavedFile = "DiaryTranscription.lastSavedFile"
  }
}
