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
OWN-WORLD: Native typography, fine rules, tactile signal views, and a deliberate private/public boundary.
STORY: Choose a destination, speak or type, continue later, then open the exact file in Obsidian.
FIRST VIEWPORT: Mode, destination, input state, and one unmistakable record action.
FORM: A compact macOS menu-bar utility; Stats is a ledger, not a second product.
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
    .background(palette.canvas)
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
    HStack(spacing: 11) {
      Image(systemName: destinationSymbol)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(palette.signal)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text("ADDING TO")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(0.8)
          .foregroundStyle(palette.secondaryText)
        Text(model.destinationDetail)
          .font(.callout.weight(.medium))
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      Button {
        showsDestinations.toggle()
      } label: {
        Label("Change", systemImage: "chevron.up.chevron.down")
          .labelStyle(.titleAndIcon)
      }
      .buttonStyle(.plain)
      .fixedSize()
      .disabled(
        model.vaultPath == nil
          || model.capture.isRecording
          || model.workflowState.isBusy
          || model.isSaving
      )
      .popover(isPresented: $showsDestinations, arrowEdge: .bottom) {
        destinationPopover
          .environment(\.diaryPalette, palette)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 11)
    .background(palette.elevated)
    .accessibilityElement(children: .contain)
  }

  private var destinationPopover: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("ENTRY DESTINATION")
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 8)
        .padding(.bottom, 3)
      destinationButton(
        "Today’s private diary",
        detail: "A timestamped entry under Diary/",
        symbol: "calendar"
      ) {
        model.useTodayDiary()
      }
      destinationButton(
        "Continue existing file…",
        detail: "Append to any Markdown file in this vault",
        symbol: "doc.text.magnifyingglass"
      ) {
        Task { await model.chooseExistingEntry() }
      }
      Hairline()
        .padding(.vertical, 3)
      destinationButton(
        "Start private blog draft…",
        detail: "Create under Writing/ and keep adding later",
        symbol: "doc.badge.plus"
      ) {
        Task { await model.createBlogDraft() }
      }
    }
    .padding(10)
    .frame(width: 300)
    .background(palette.canvas)
    .foregroundStyle(palette.text)
  }

  private func destinationButton(
    _ title: String,
    detail: String,
    symbol: String,
    action: @escaping () -> Void
  ) -> some View {
    Button {
      showsDestinations = false
      action()
    } label: {
      HStack(spacing: 10) {
        Image(systemName: symbol)
          .frame(width: 18)
          .foregroundStyle(palette.signal)
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.callout.weight(.medium))
          Text(detail)
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
        Spacer()
      }
      .contentShape(Rectangle())
      .padding(8)
    }
    .buttonStyle(.plain)
  }

  private var destinationSymbol: String {
    switch model.entryDestination {
    case .todayDiary: "calendar"
    case .existing(let relativePath) where relativePath.hasPrefix("Writing/"): "text.book.closed"
    case .existing: "doc.text"
    }
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
      VStack(alignment: .leading, spacing: 4) {
        Text("Your yap, in pixels")
          .font(.system(size: 20, weight: .semibold, design: .rounded))
        Text("Stored on this Mac. Nothing here is uploaded.")
          .font(.callout)
          .foregroundStyle(palette.secondaryText)
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 15)

      Hairline()

      VStack(spacing: 0) {
        metricRow("VOICE ENTRIES", value: "\(model.usageStats.voiceEntries)")
        Hairline()
        metricRow("WORDS CAPTURED", value: model.usageStats.totalWords.formatted())
        Hairline()
        metricRow("MINUTES SPOKEN", value: spokenMinutes)
        Hairline()
        metricRow("CURRENT STREAK", value: "\(model.usageStats.currentStreak()) days")
      }
      .background(palette.field)

      Hairline()

      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("LAST 7 DAYS")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.8)
          Spacer()
          Text("words")
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
        PixelWeekView(days: model.usageStats.recentDays())
          .frame(height: 116)
        if model.usageStats.totalEntries == 0 {
          Text("Your first saved entry will light up this ledger.")
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
      }
      .padding(18)
    }
  }

  private var spokenMinutes: String {
    let minutes = model.usageStats.audioSeconds / 60
    return minutes < 10 ? String(format: "%.1f", minutes) : String(format: "%.0f", minutes)
  }

  private func metricRow(_ label: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(palette.secondaryText)
      Spacer()
      Text(value)
        .font(.system(size: 18, weight: .semibold, design: .monospaced))
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 11)
  }
}

private struct PixelWeekView: View {
  let days: [DiaryUsageStats.DaySnapshot]
  @Environment(\.diaryPalette) private var palette

  var body: some View {
    GeometryReader { proxy in
      let maxWords = max(1, days.map(\.words).max() ?? 1)
      HStack(alignment: .bottom, spacing: 11) {
        ForEach(days) { day in
          VStack(spacing: 6) {
            VStack(spacing: 3) {
              ForEach((0..<8).reversed(), id: \.self) { row in
                let threshold = Double(row + 1) / 8
                Rectangle()
                  .fill(
                    Double(day.words) / Double(maxWords) >= threshold
                      ? palette.signal
                      : palette.signal.opacity(0.1)
                  )
                  .frame(height: 7)
              }
            }
            Text(day.label)
              .font(.system(size: 9, weight: .bold, design: .monospaced))
              .foregroundStyle(palette.secondaryText)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(day.id), \(day.words) words")
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}
