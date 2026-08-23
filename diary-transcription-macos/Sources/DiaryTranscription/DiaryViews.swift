import AppKit
import SwiftUI

enum DiaryMode: String, CaseIterable, Identifiable {
  case speak
  case write
  case stats

  var id: String { rawValue }

  var title: String {
    switch self {
    case .speak: "Speak"
    case .write: "Write"
    case .stats: "Stats"
    }
  }
}

struct StatusView: View {
  let status: DiaryAppModel.Status
  @Environment(\.diaryPalette) private var palette

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: status.symbolName)
        .foregroundStyle(color)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(status.title).font(.callout.weight(.semibold))
        Text(status.detail)
          .font(.caption)
          .foregroundStyle(palette.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var color: Color {
    switch status {
    case .ready: palette.secondaryText
    case .saved: palette.signal
    case .error: palette.record
    }
  }
}

/*
THESIS: One calm control surface turns unfinished speech into durable Obsidian writing.
OWN-WORLD: Native typography, fine rules, tactile signals, and ordered pixels that always encode real data.
STORY: Choose Diary, Blog, Notes, or any Markdown file; append by voice or text and resume later.
FIRST VIEWPORT: Mode, active file, live input state, and one unmistakable record action.
FORM: A compact macOS menu-bar utility with a destination studio and one dithered stats chart.
*/
struct MenuBarContentView: View {
  @Bindable var model: DiaryAppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var mode = DiaryMode.speak

  private var palette: DiaryPalette { model.themeChoice.palette }

  init(model: DiaryAppModel, initialMode: DiaryMode = .speak) {
    self.model = model
    _mode = State(initialValue: initialMode)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      modePicker
      Hairline()
      modeContent
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .id(mode)
      Hairline()
      footer
    }
    .background {
      ZStack {
        palette.canvas
        if model.themeChoice.usesDitherTexture {
          DitherBackdrop(color: palette.signal.opacity(0.09))
        }
      }
    }
    .foregroundStyle(palette.text)
    .frame(width: 420)
    .environment(\.diaryPalette, palette)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: mode)
    .task { await model.restoreVault() }
  }

  private var header: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Diary")
          .font(.system(size: 18, weight: .semibold, design: .rounded))
        Text("Local voice → Obsidian")
          .font(.caption)
          .foregroundStyle(palette.secondaryText)
      }
      Spacer()
      HStack(spacing: 5) {
        Circle()
          .fill(model.destinationExists ? palette.signal : palette.record)
          .frame(width: 6, height: 6)
        Text(model.destinationExists ? "VAULT READY" : "SETUP NEEDED")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(0.7)
      }
      .foregroundStyle(palette.secondaryText)
      .accessibilityElement(children: .combine)
    }
    .padding(.horizontal, 18)
    .padding(.top, 15)
    .padding(.bottom, 11)
  }

  private var modePicker: some View {
    HStack(spacing: 3) {
      ForEach(DiaryMode.allCases) { item in
        Button {
          if reduceMotion {
            mode = item
          } else {
            withAnimation(.easeInOut(duration: 0.22)) { mode = item }
          }
        } label: {
          Text(item.title)
            .font(.callout.weight(mode == item ? .semibold : .regular))
            .foregroundStyle(mode == item ? palette.text : palette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(mode == item ? palette.field : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == item ? .isSelected : [])
      }
    }
    .padding(3)
    .background(palette.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Capture mode")
    .disabled(model.capture.isRecording || model.workflowState.isBusy || model.isSaving)
    .padding(.horizontal, 18)
    .padding(.bottom, 13)
  }

  @ViewBuilder
  private var modeContent: some View {
    switch mode {
    case .speak:
      SpeakModeView(model: model)
    case .write:
      WritingModeView(model: model)
    case .stats:
      StatsModeView(model: model)
    }
  }

  private var footer: some View {
    HStack(spacing: 15) {
      Button {
        DiarySettingsWindowController.shared.show(model: model)
      } label: {
        Label("Settings", systemImage: "gearshape")
      }
      .buttonStyle(.plain)
      .help("Open Diary Transcription Settings")

      Spacer()
      Image(systemName: "lock.fill")
        .accessibilityLabel("Audio and transcription stay on this Mac")
        .help("Audio and transcription stay on this Mac")
      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Image(systemName: "power")
          .accessibilityLabel("Quit Diary Transcription")
      }
      .buttonStyle(.plain)
      .disabled(model.capture.isRecording || model.workflowState.isBusy)
      .help(
        model.capture.isRecording || model.workflowState.isBusy
          ? "Finish the current entry before quitting"
          : "Quit Diary Transcription"
      )
    }
    .font(.caption)
    .foregroundStyle(palette.secondaryText)
    .padding(.horizontal, 18)
    .padding(.vertical, 13)
  }
}

private struct DestinationBar: View {
  @Bindable var model: DiaryAppModel
  @Environment(\.diaryPalette) private var palette
  @State private var showsDestinations = false

  var body: some View {
    Button {
      showsDestinations.toggle()
    } label: {
      HStack(spacing: 11) {
        ZStack {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(palette.signal.opacity(0.13))
          Image(systemName: model.destinationWorkspace.symbolName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.signal)
        }
        .frame(width: 34, height: 34)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text("ADDING TO")
              .font(.system(size: 9, weight: .bold, design: .monospaced))
              .tracking(0.8)
              .foregroundStyle(palette.secondaryText)
            Text(model.destinationWorkspace.title.uppercased())
              .font(.system(size: 8, weight: .bold, design: .monospaced))
              .foregroundStyle(palette.signal)
          }
          Text(model.destinationDetail)
            .font(.callout.weight(.medium))
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 2) {
          Text("Resume / switch")
            .font(.caption.weight(.medium))
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(palette.secondaryText)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
    .background(palette.elevated)
    .disabled(
      model.vaultPath == nil
        || model.capture.isRecording
        || model.workflowState.isBusy
        || model.isSaving
    )
    .popover(isPresented: $showsDestinations, arrowEdge: .bottom) {
      DestinationStudioView(
        model: model,
        workspace: $model.selectedWorkspace
      ) {
        showsDestinations = false
      }
      .environment(\.diaryPalette, palette)
    }
    .accessibilityLabel("Writing destination")
    .accessibilityValue(model.destinationDetail)
    .accessibilityHint("Choose a new file, folder, or existing Markdown file")
  }
}

struct DestinationStudioView: View {
  @Bindable var model: DiaryAppModel
  @Binding var workspace: EntryWorkspace
  let dismiss: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.diaryPalette) private var palette
  @State private var isNamingFolder = false
  @State private var folderName = ""
  @FocusState private var folderFieldFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Where should this thought continue?")
          .font(.system(size: 17, weight: .semibold, design: .rounded))
        Text("Existing Markdown is preserved. Every capture appends at the end.")
          .font(.caption)
          .foregroundStyle(palette.secondaryText)
      }
      .padding(.bottom, 13)

      workspacePicker
      folderStrip
        .padding(.top, 10)
        .padding(.bottom, 11)

      Hairline()

      if isNamingFolder {
        folderForm
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      } else {
        actionList
          .transition(.opacity.combined(with: .move(edge: .leading)))
      }

      let recent = Array(model.recentDestinations(for: workspace).prefix(3))
      if !isNamingFolder, !recent.isEmpty {
        Hairline()
        recentList(recent)
      }
    }
    .padding(14)
    .frame(width: 356)
    .background(palette.canvas)
    .foregroundStyle(palette.text)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isNamingFolder)
  }

  private var workspacePicker: some View {
    HStack(spacing: 5) {
      ForEach(EntryWorkspace.allCases) { item in
        Button {
          workspace = item
          isNamingFolder = false
          folderName = ""
        } label: {
          VStack(spacing: 5) {
            Image(systemName: item.symbolName)
              .font(.system(size: 14, weight: .semibold))
            Text(item.title)
              .font(.system(size: 10, weight: .semibold))
              .lineLimit(1)
          }
          .foregroundStyle(workspace == item ? palette.controlInk : palette.secondaryText)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(workspace == item ? palette.signal : palette.field)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(workspace == item ? .isSelected : [])
        .help(item.detail)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Writing workspace")
  }

  private var folderStrip: some View {
    HStack(spacing: 8) {
      Image(systemName: "folder.fill")
        .foregroundStyle(palette.signal)
      VStack(alignment: .leading, spacing: 1) {
        Text(workspace.detail)
          .font(.caption.weight(.medium))
        Text(folderPath)
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(palette.secondaryText)
          .lineLimit(1)
      }
      Spacer()
      if model.destinationWorkspace == workspace {
        Label("Current", systemImage: "checkmark")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(palette.signal)
      }
    }
  }

  @ViewBuilder
  private var actionList: some View {
    VStack(spacing: 0) {
      if workspace == .diary {
        actionButton(
          "Use today’s diary",
          detail: "A timestamped private entry in Diary/",
          symbol: "calendar.badge.plus"
        ) {
          dismiss()
          model.useTodayDiary()
        }
      } else {
        actionButton(
          workspace == .blog ? "New blog draft…" : "New Markdown file…",
          detail: workspace == .blog
            ? "Private by default and ready for Quartz later"
            : "Create it in \(folderPath)",
          symbol: "doc.badge.plus"
        ) {
          dismiss()
          Task { await model.createNewEntry(in: workspace) }
        }
      }

      Hairline().padding(.leading, 33)

      actionButton(
        workspace == .anyMarkdown ? "Select any Markdown file…" : "Continue existing file…",
        detail: "Resume from the end without replacing anything",
        symbol: "arrow.down.doc"
      ) {
        dismiss()
        Task { await model.chooseExistingEntry(in: workspace) }
      }

      if workspace != .diary {
        Hairline().padding(.leading, 33)
        actionButton(
          "New folder + file…",
          detail: "Organize a new thread inside \(folderPath)",
          symbol: "folder.badge.plus"
        ) {
          folderName = ""
          isNamingFolder = true
          Task { @MainActor in folderFieldFocused = true }
        }
      }
    }
    .padding(.vertical, 4)
  }

  private var folderForm: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("New folder")
            .font(.callout.weight(.semibold))
          Text("Created inside \(folderPath), then you will name its first file.")
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
        Spacer()
      }

      TextField("Folder name", text: $folderName)
        .textFieldStyle(.roundedBorder)
        .focused($folderFieldFocused)
        .onSubmit(createFolder)

      HStack {
        Button("Back") {
          isNamingFolder = false
          folderName = ""
        }
        Spacer()
        Button("Create folder") { createFolder() }
          .buttonStyle(.borderedProminent)
          .tint(palette.signal)
          .disabled(cleanFolderName.isEmpty)
      }
    }
    .padding(.vertical, 12)
  }

  private func recentList(_ recent: [DiaryAppModel.RecentDestination]) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("RECENT")
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(palette.secondaryText)
        .padding(.top, 10)
        .padding(.bottom, 2)
      ForEach(recent) { item in
        Button {
          dismiss()
          model.resumeExisting(relativePath: item.relativePath)
        } label: {
          HStack(spacing: 9) {
            Image(systemName: item.workspace.symbolName)
              .foregroundStyle(palette.signal)
              .frame(width: 17)
            VStack(alignment: .leading, spacing: 1) {
              Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
              Text(item.relativePath)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.turn.down.right")
              .font(.caption2)
              .foregroundStyle(palette.secondaryText)
          }
          .contentShape(Rectangle())
          .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func actionButton(
    _ title: String,
    detail: String,
    symbol: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: symbol)
          .foregroundStyle(palette.signal)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.callout.weight(.medium))
          Text(detail)
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
            .lineLimit(2)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
          .foregroundStyle(palette.secondaryText)
      }
      .contentShape(Rectangle())
      .padding(.vertical, 9)
      .padding(.horizontal, 2)
    }
    .buttonStyle(.plain)
  }

  private var folderPath: String {
    workspace.directoryRelativePath.isEmpty ? "Vault/" : "\(workspace.directoryRelativePath)/"
  }

  private var cleanFolderName: String {
    folderName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func createFolder() {
    guard !cleanFolderName.isEmpty else { return }
    let requestedName = cleanFolderName
    dismiss()
    Task { await model.createFolderAndEntry(in: workspace, folderName: requestedName) }
  }
}

private struct SpeakModeView: View {
  @Bindable var model: DiaryAppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.diaryPalette) private var palette
  @State private var recordHovered = false

  private var capture: AudioCaptureModel { model.capture }

  var body: some View {
    VStack(spacing: 0) {
      DestinationBar(model: model)
      Hairline()
      VStack(spacing: 12) {
        VStack(spacing: 3) {
          Text(captureTitle)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .contentTransition(.opacity)
          Text(captureDetail)
            .font(.callout)
            .foregroundStyle(palette.secondaryText)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 48)

        AudioVisualizationView(
          capture: capture,
          style: model.visualizationStyle
        )

        Text(capture.formattedDuration)
          .font(.system(size: 15, weight: .medium, design: .monospaced))
          .foregroundStyle(capture.isRecording ? palette.text : palette.secondaryText)
          .contentTransition(.numericText(countsDown: false))
          .accessibilityLabel("Recording duration")

        recordControl
        captureActions.frame(minHeight: 25)
      }
      .padding(.horizontal, 18)
      .padding(.top, 16)
      .padding(.bottom, 15)
      .background(palette.field)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.workflowState)

      Hairline()
      setupStrip
    }
  }

  private var recordControl: some View {
    Button {
      Task { await model.handlePrimaryAction() }
    } label: {
      ZStack {
        if capture.isRecording {
          Circle()
            .stroke(palette.record.opacity(0.32), lineWidth: 2)
            .frame(width: 82, height: 82)
            .scaleEffect(reduceMotion ? 1 : 0.98 + capture.inputLevel * 0.12)
        }
        Circle()
          .fill(capture.isRecording ? palette.record.opacity(0.2) : palette.record)
          .frame(width: 70, height: 70)
        if capture.isRecording {
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(palette.record)
            .frame(width: 25, height: 25)
        } else if isProcessing || capture.phase == .requestingPermission {
          ProgressView().controlSize(.small).tint(palette.controlInk)
        } else {
          Image(systemName: "mic.fill")
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(palette.controlInk)
        }
      }
      .scaleEffect(recordHovered && !recordButtonDisabled ? 1.035 : 1)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(recordButtonDisabled)
    .opacity(recordButtonDisabled ? 0.42 : 1)
    .onHover { recordHovered = $0 }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: recordHovered)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: capture.inputLevel)
    .accessibilityLabel(capture.isRecording ? "Stop and transcribe" : "Start recording")
    .accessibilityHint(recordButtonHint)
  }

  @ViewBuilder
  private var captureActions: some View {
    switch model.workflowState {
    case .transcribing:
      Label("Transcribing locally…", systemImage: "waveform.badge.magnifyingglass")
        .font(.caption).foregroundStyle(palette.secondaryText)
    case .saving:
      Label("Appending safely to \(model.destinationTitle)…", systemImage: "arrow.down.doc")
        .font(.caption).foregroundStyle(palette.secondaryText)
    case .saved(let fileName, _):
      HStack(spacing: 14) {
        Label(fileName, systemImage: "checkmark.circle.fill")
          .font(.caption).foregroundStyle(palette.signal)
          .lineLimit(1)
        Button("Open in Obsidian") { Task { await model.openLastSavedEntry() } }
          .buttonStyle(.link)
      }
    case .failed where model.hasPendingRecording:
      recoveryActions
    default:
      capturePhaseActions
    }
  }

  private var recoveryActions: some View {
    HStack(spacing: 13) {
      Button("Retry") { Task { await model.retryPendingRecording() } }
      Button("Show audio") {
        if let url = capture.capturedURL {
          NSWorkspace.shared.activateFileViewerSelecting([url])
        }
      }
      Button("Discard", role: .destructive) { model.discardPendingRecording() }
    }
    .buttonStyle(.link)
  }

  @ViewBuilder
  private var capturePhaseActions: some View {
    switch capture.phase {
    case .captured, .interrupted:
      recoveryActions
    case .permissionDenied:
      HStack(spacing: 14) {
        Button("Open Privacy Settings") { openMicrophoneSettings() }
        Button("Try again") { capture.resetPermissionState() }
      }
      .buttonStyle(.link)
    default:
      Text(actionHint)
        .font(.caption)
        .foregroundStyle(palette.secondaryText)
    }
  }

  @ViewBuilder
  private var setupStrip: some View {
    if model.vaultPath == nil {
      setupRow(
        symbol: "folder.badge.questionmark",
        title: "Connect your Obsidian vault",
        detail: "Diary/ and Writing/ stay in your vault"
      ) {
        Button("Choose…") { Task { await model.chooseVault() } }
          .buttonStyle(.bordered).controlSize(.small)
      }
    } else if !model.modelState.isUsable {
      setupRow(
        symbol: "square.and.arrow.down",
        title: "Install local transcription",
        detail: modelDetail
      ) {
        if case .downloading = model.modelState {
          ProgressView(value: modelProgress).frame(width: 76)
        } else {
          Button("Install…") { Task { await model.installModel() } }
            .buttonStyle(.bordered).controlSize(.small)
        }
      }
    } else {
      HStack(spacing: 7) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(palette.signal)
        Text("Offline model ready")
        Spacer()
        Text(model.shortcut?.displayName ?? "No shortcut")
          .foregroundStyle(palette.secondaryText)
      }
      .font(.caption)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
    }
  }

  private func setupRow<Accessory: View>(
    symbol: String,
    title: String,
    detail: String,
    @ViewBuilder accessory: () -> Accessory
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .frame(width: 17)
        .foregroundStyle(palette.secondaryText)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.callout.weight(.medium))
        Text(detail).font(.caption).foregroundStyle(palette.secondaryText).lineLimit(1)
      }
      Spacer()
      accessory()
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 11)
  }

  private var captureTitle: String {
    switch model.workflowState {
    case .transcribing: return "Turning speech into text"
    case .saving: return "Saving your entry"
    case .saved: return "Entry saved"
    case .failed where model.hasPendingRecording: return "Your recording is safe"
    default: break
    }
    if model.vaultPath == nil, capture.phase == .idle { return "Connect your vault" }
    if !model.destinationExists, capture.phase == .idle { return "Choose the file again" }
    if !model.modelState.isUsable, capture.phase == .idle { return "Finish local setup" }
    return switch capture.phase {
    case .idle: "Ready when you are"
    case .requestingPermission: "Checking microphone…"
    case .recording: "Listening"
    case .captured: "Recording held locally"
    case .interrupted: "Recording interrupted"
    case .permissionDenied: "Microphone access is off"
    case .failed: "Capture needs attention"
    }
  }

  private var captureDetail: String {
    switch model.workflowState {
    case .transcribing: return "Cohere runs on your Mac. Audio is not uploaded."
    case .saving: return "The coordinated append preserves everything already in the file."
    case .saved(_, let preview): return preview
    case .failed(let message): return message
    default: break
    }
    if model.vaultPath == nil, capture.phase == .idle {
      return "Choose the folder that contains your Obsidian vault."
    }
    if !model.destinationExists, capture.phase == .idle {
      return "The previous destination moved or was renamed. Change the destination above."
    }
    if !model.modelState.isUsable, capture.phase == .idle {
      return "Install the one-time 2.42 GB INT8 model. It works offline afterward."
    }
    return switch capture.phase {
    case .idle: "Speak naturally. The signal responds only to microphone input."
    case .requestingPermission: "macOS may ask for permission once."
    case .recording: "Stop when you are done; this entry will append to \(model.destinationTitle)."
    case .captured: "Ready to retry local transcription."
    case .interrupted(let message): message
    case .permissionDenied: "Allow Diary Transcription in Privacy & Security, then try again."
    case .failed(let message): message
    }
  }

  private var isProcessing: Bool { model.workflowState.isBusy }
  private var recordButtonDisabled: Bool {
    if capture.isRecording { return false }
    return !model.canRecord || capture.phase == .requestingPermission || isProcessing
  }

  private var recordButtonHint: String {
    if capture.isRecording { return "Stops, transcribes, and appends to the selected file" }
    if model.vaultPath == nil { return "Choose an Obsidian vault first" }
    if !model.destinationExists { return "Choose an existing destination first" }
    if !model.modelState.isUsable { return "Install the local model first" }
    if model.hasPendingRecording { return "Retry or discard the pending recording first" }
    return "Begins local microphone capture"
  }

  private var actionHint: String {
    if capture.isRecording {
      return model.shortcut.map { "Press \($0.displayName) or the stop button when you’re done." }
        ?? "Press the stop button when you’re done."
    }
    if model.canRecord {
      return model.shortcut.map { "Press \($0.displayName) or the microphone to begin." }
        ?? "Press the microphone to begin."
    }
    return "Complete the setup below to begin."
  }

  private var modelProgress: Double {
    if case .downloading(let value) = model.modelState { return value }
    return 0
  }

  private var modelDetail: String {
    switch model.modelState {
    case .notInstalled: "2.42 GB · first download only"
    case .downloading(let value): "Downloading · \(Int(value * 100))%"
    case .installed: "2.42 GB · loads when recording starts"
    case .loading: "Loading into memory…"
    case .ready: "Ready offline"
    case .failed(let message): message
    }
  }

  private func openMicrophoneSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    else { return }
    NSWorkspace.shared.open(url)
  }
}

private struct WritingModeView: View {
  @Bindable var model: DiaryAppModel
  @Environment(\.diaryPalette) private var palette

  var body: some View {
    VStack(spacing: 0) {
      DestinationBar(model: model)
      Hairline()
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Continue the thought")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
          Text("Typed text and future recordings can share this same file.")
            .font(.callout)
            .foregroundStyle(palette.secondaryText)
        }

        TextEditor(text: $model.testEntry)
          .font(.body)
          .scrollContentBackground(.hidden)
          .padding(8)
          .frame(minHeight: 190)
          .background(palette.elevated)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(palette.hairline, lineWidth: 1)
          }
          .foregroundStyle(palette.text)
          .accessibilityLabel("Entry text")

        HStack {
          Text("\(DiaryUsageStats.wordCount(model.testEntry)) words")
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.secondaryText)
          Spacer()
          Button {
            Task { await model.saveTestEntry() }
          } label: {
            if model.isSaving {
              ProgressView().controlSize(.small)
            } else {
              Label("Append to \(model.destinationTitle)", systemImage: "arrow.down.doc")
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(palette.signal)
          .disabled(saveDisabled)
        }

        if case .saved = model.workflowState {
          Button("Open saved entry in Obsidian") {
            Task { await model.openLastSavedEntry() }
          }
          .buttonStyle(.link)
        }

        StatusView(status: model.status)
          .padding(.top, 3)
      }
      .padding(18)
      .background(palette.field)
    }
  }

  private var saveDisabled: Bool {
    model.isSaving
      || model.workflowState.isBusy
      || model.capture.isRecording
      || model.vaultPath == nil
      || !model.destinationExists
      || model.testEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

private struct StatsModeView: View {
  @Bindable var model: DiaryAppModel
  @Environment(\.diaryPalette) private var palette

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline) {
          Text("Writing signal")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
          Spacer()
          Label("LOCAL", systemImage: "lock.fill")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(palette.signal)
        }
        Text(summaryLine)
          .font(.callout)
          .foregroundStyle(palette.secondaryText)
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 14)

      Hairline()

      DitherWordChart(days: model.usageStats.recentDays(count: 14))
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .background(palette.field)

      Hairline()

      HStack(spacing: 0) {
        metric("Entries", value: model.usageStats.totalEntries.formatted())
        verticalHairline
        metric("Voice", value: model.usageStats.voiceEntries.formatted())
        verticalHairline
        metric("Minutes", value: spokenMinutes)
        verticalHairline
        metric("Streak", value: "\(model.usageStats.currentStreak())d")
      }
      .padding(.vertical, 12)

      if model.usageStats.totalEntries == 0 {
        Hairline()
        HStack(spacing: 9) {
          Image(systemName: "square.grid.3x3")
            .foregroundStyle(palette.signal)
          Text("Your first saved entry will switch on this fourteen-day signal.")
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
        .padding(18)
      }
    }
  }

  private var summaryLine: String {
    if model.usageStats.totalEntries == 0 {
      return "A private, pixel-by-pixel view of your writing rhythm."
    }
    return
      "\(model.usageStats.totalWords.formatted()) words captured across \(model.usageStats.totalEntries.formatted()) saved entries."
  }

  private var spokenMinutes: String {
    let minutes = model.usageStats.audioSeconds / 60
    return minutes < 10 ? String(format: "%.1f", minutes) : String(format: "%.0f", minutes)
  }

  private func metric(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(value)
        .font(.system(size: 17, weight: .semibold, design: .monospaced))
        .contentTransition(.numericText())
      Text(label)
        .font(.caption2)
        .foregroundStyle(palette.secondaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .accessibilityElement(children: .combine)
  }

  private var verticalHairline: some View {
    Rectangle()
      .fill(palette.hairline)
      .frame(width: 1, height: 36)
      .accessibilityHidden(true)
  }
}

private struct DitherWordChart: View {
  let days: [DiaryUsageStats.DaySnapshot]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.diaryPalette) private var palette
  @State private var selectedIndex: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 1) {
          Text("LAST 14 DAYS")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.8)
          Text("Ordered pixels show words saved each day")
            .font(.caption2)
            .foregroundStyle(palette.secondaryText)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 1) {
          Text(focusedDay.words.formatted())
            .font(.system(size: 19, weight: .semibold, design: .monospaced))
            .contentTransition(.numericText())
          Text("\(focusedDay.id) · words")
            .font(.caption2)
            .foregroundStyle(palette.secondaryText)
        }
      }

      GeometryReader { proxy in
        let plotHeight = max(1, proxy.size.height - 19)
        let maxWords = max(1, days.map(\.words).max() ?? 1)
        let focusIndex = min(selectedIndex ?? max(0, days.count - 1), max(0, days.count - 1))
        let focusPoint = point(
          for: focusIndex,
          size: CGSize(width: proxy.size.width, height: plotHeight),
          maxWords: maxWords
        )

        ZStack(alignment: .topLeading) {
          Canvas(rendersAsynchronously: true) { context, size in
            drawChart(
              context: &context,
              size: CGSize(width: size.width, height: plotHeight),
              maxWords: maxWords
            )
          }
          .frame(height: plotHeight)
          .shadow(color: palette.signal.opacity(0.16), radius: 5, x: 1, y: 2)

          Rectangle()
            .fill(palette.text.opacity(selectedIndex == nil ? 0 : 0.15))
            .frame(width: 1, height: plotHeight)
            .position(x: focusPoint.x, y: plotHeight / 2)

          Circle()
            .fill(palette.canvas)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(palette.signal, lineWidth: 2))
            .position(focusPoint)
            .shadow(color: palette.signal.opacity(0.22), radius: 4, x: 1, y: 2)

          dayLabels
            .frame(width: proxy.size.width, height: 18)
            .offset(y: plotHeight + 2)
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
          switch phase {
          case .active(let location):
            updateSelection(x: location.x, width: proxy.size.width)
          case .ended:
            setSelection(nil)
          }
        }
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              updateSelection(x: value.location.x, width: proxy.size.width)
            }
            .onEnded { _ in setSelection(nil) }
        )
      }
      .frame(height: 148)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Words captured during the last fourteen days")
      .accessibilityValue("\(focusedDay.id), \(focusedDay.words) words")
    }
  }

  private var focusedDay: DiaryUsageStats.DaySnapshot {
    guard !days.isEmpty else {
      return DiaryUsageStats.DaySnapshot(
        id: "No data",
        label: "–",
        words: 0,
        entries: 0,
        audioSeconds: 0
      )
    }
    return days[min(selectedIndex ?? days.count - 1, days.count - 1)]
  }

  private var dayLabels: some View {
    HStack(spacing: 0) {
      ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
        Text(index.isMultiple(of: 2) || index == days.count - 1 ? day.label : "·")
          .font(.system(size: 8, weight: .bold, design: .monospaced))
          .foregroundStyle(
            selectedIndex == index ? palette.signal : palette.secondaryText.opacity(0.84)
          )
          .frame(maxWidth: .infinity)
      }
    }
  }

  private func drawChart(
    context: inout GraphicsContext,
    size: CGSize,
    maxWords: Int
  ) {
    for fraction in [0.0, 0.5, 1.0] {
      var grid = Path()
      let y = size.height * (1 - fraction)
      grid.move(to: CGPoint(x: 0, y: y))
      grid.addLine(to: CGPoint(x: size.width, y: y))
      context.stroke(grid, with: .color(palette.hairline), lineWidth: 1)
    }

    let step: CGFloat = 4
    let bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    for x in stride(from: CGFloat.zero, through: size.width, by: step) {
      let interpolated = interpolatedWords(at: x, width: size.width)
      let normalized = min(1, interpolated / Double(maxWords))
      let top = size.height * (1 - CGFloat(normalized))
      for y in stride(from: top, through: size.height, by: step) {
        let column = Int(x / step)
        let row = Int(y / step)
        let threshold = Double(bayer[(row % 4) * 4 + (column % 4)]) / 16
        let verticalDensity = 0.48 + 0.42 * Double((y - top) / max(1, size.height - top))
        guard threshold <= verticalDensity else { continue }
        context.fill(
          Path(CGRect(x: x, y: y, width: 2, height: 2)),
          with: .color(palette.signal.opacity(0.78))
        )
      }
    }

    var line = Path()
    for index in days.indices {
      let chartPoint = point(for: index, size: size, maxWords: maxWords)
      if index == days.startIndex {
        line.move(to: chartPoint)
      } else {
        line.addLine(to: chartPoint)
      }
    }
    context.stroke(
      line,
      with: .color(palette.signal),
      style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
    )
  }

  private func interpolatedWords(at x: CGFloat, width: CGFloat) -> Double {
    guard days.count > 1, width > 0 else { return Double(days.first?.words ?? 0) }
    let position = min(
      Double(days.count - 1),
      max(0, Double(x / width) * Double(days.count - 1))
    )
    let lower = Int(floor(position))
    let upper = min(days.count - 1, lower + 1)
    let fraction = position - Double(lower)
    return Double(days[lower].words) * (1 - fraction) + Double(days[upper].words) * fraction
  }

  private func point(for index: Int, size: CGSize, maxWords: Int) -> CGPoint {
    guard !days.isEmpty else { return CGPoint(x: 0, y: size.height) }
    let x =
      days.count == 1
      ? size.width / 2
      : CGFloat(index) / CGFloat(days.count - 1) * size.width
    let normalized = CGFloat(days[index].words) / CGFloat(maxWords)
    return CGPoint(x: x, y: size.height * (1 - normalized))
  }

  private func updateSelection(x: CGFloat, width: CGFloat) {
    guard !days.isEmpty, width > 0 else { return }
    let index = Int(
      round(min(1, max(0, x / width)) * CGFloat(max(0, days.count - 1)))
    )
    setSelection(index)
  }

  private func setSelection(_ value: Int?) {
    if reduceMotion {
      selectedIndex = value
    } else {
      withAnimation(.easeOut(duration: 0.16)) { selectedIndex = value }
    }
  }
}
