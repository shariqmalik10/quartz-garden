import AppKit
import SwiftUI

struct StatusView: View {
    let status: DiaryAppModel.Status

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.symbolName)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title).font(.headline)
                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch status {
        case .ready: .secondary
        case .saved: .green
        case .error: .red
        }
    }
}

struct TestEntryView: View {
    @Bindable var model: DiaryAppModel
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !compact { Text("Write instead").font(.headline) }
            TextEditor(text: $model.testEntry)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(minHeight: compact ? 72 : 96)
                .background(compact ? DiaryDesign.field : Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(compact ? DiaryDesign.hairline : Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .foregroundStyle(compact ? DiaryDesign.text : .primary)
                .accessibilityLabel("Diary entry")

            Button {
                Task { await model.saveTestEntry() }
            } label: {
                if model.isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Append to today’s diary", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(compact ? DiaryDesign.signal : nil)
            .disabled(
                model.isSaving
                    || model.workflowState.isBusy
                    || model.capture.isRecording
                    || model.vaultPath == nil
                    || model.testEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            if compact {
                StatusView(status: model.status).padding(.top, 2)
            }
        }
    }
}

/*
THESIS: A private listening field makes voice capture feel calm, local, and trustworthy.
OWN-WORLD: Deep graphite, warm white, sea-glass signal, and coral only for record/stop.
STORY: Connect once, speak naturally, then watch local transcription become a durable note.
FIRST VIEWPORT: Readiness, live sound, duration, and one unambiguous capture action.
FORM: Native macOS menu-bar utility with a quiet, focused settings surface.
*/
struct MenuBarContentView: View {
    @Bindable var model: DiaryAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWriting = false

    private var capture: AudioCaptureModel { model.capture }

    var body: some View {
        VStack(spacing: 0) {
            header
            captureField
            readinessStrip

            if showsWriting {
                Hairline()
                TestEntryView(model: model, compact: true)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Hairline()
            footer
        }
        .background(DiaryDesign.canvas)
        .foregroundStyle(DiaryDesign.text)
        .frame(width: 404)
        .task { await model.restoreVault() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Diary")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Private capture · transcribed on this Mac")
                    .font(.caption)
                    .foregroundStyle(DiaryDesign.secondaryText)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(DiaryDesign.signal)
                .accessibilityLabel("Local and private")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    private var captureField: some View {
        VStack(spacing: 14) {
            VStack(spacing: 3) {
                Text(captureTitle)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .contentTransition(.opacity)
                Text(captureDetail)
                    .font(.callout)
                    .foregroundStyle(DiaryDesign.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 46)

            AudioWaveformView(capture: capture)

            Text(capture.formattedDuration)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(capture.isRecording ? DiaryDesign.text : DiaryDesign.secondaryText)
                .contentTransition(.numericText(countsDown: false))
                .accessibilityLabel("Recording duration")

            recordControl
            captureActions.frame(minHeight: 24)
        }
        .padding(.horizontal, 18)
        .padding(.top, 17)
        .padding(.bottom, 16)
        .background(DiaryDesign.field)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.workflowState)
    }

    private var recordControl: some View {
        Button {
            Task { await model.handlePrimaryAction() }
        } label: {
            ZStack {
                if capture.isRecording && !reduceMotion {
                    Circle()
                        .stroke(DiaryDesign.record.opacity(0.25), lineWidth: 2)
                        .frame(width: 78, height: 78)
                        .scaleEffect(capture.inputLevel > 0.08 ? 1.08 : 0.96)
                        .opacity(capture.inputLevel > 0.08 ? 0.35 : 0.75)
                        .animation(.easeOut(duration: 0.12), value: capture.inputLevel)
                }
                Circle()
                    .fill(capture.isRecording ? DiaryDesign.record.opacity(0.18) : DiaryDesign.record)
                    .frame(width: 66, height: 66)
                if capture.isRecording {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DiaryDesign.record)
                        .frame(width: 24, height: 24)
                } else if isProcessing || capture.phase == .requestingPermission {
                    ProgressView().controlSize(.small).tint(DiaryDesign.canvas)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DiaryDesign.canvas)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(recordButtonDisabled)
        .opacity(recordButtonDisabled ? 0.42 : 1)
        .accessibilityLabel(capture.isRecording ? "Stop and transcribe" : "Start recording")
        .accessibilityHint(recordButtonHint)
    }

    @ViewBuilder
    private var captureActions: some View {
        switch model.workflowState {
        case .transcribing:
            Label("Transcribing locally…", systemImage: "waveform.badge.magnifyingglass")
                .font(.caption).foregroundStyle(DiaryDesign.secondaryText)
        case .saving:
            Label("Appending safely to Diary/…", systemImage: "arrow.down.doc")
                .font(.caption).foregroundStyle(DiaryDesign.secondaryText)
        case let .saved(fileName, _):
            HStack(spacing: 14) {
                Label(fileName, systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(DiaryDesign.signal)
                Button("Open today") { Task { await model.openTodayDiary() } }
                    .buttonStyle(.link)
            }
        case .failed where model.hasPendingRecording:
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
        default:
            capturePhaseActions
        }
    }

    @ViewBuilder
    private var capturePhaseActions: some View {
        switch capture.phase {
        case .captured, .interrupted:
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
        case .permissionDenied:
            HStack(spacing: 14) {
                Button("Open Privacy Settings") { openMicrophoneSettings() }
                Button("Try again") { capture.resetPermissionState() }
            }
            .buttonStyle(.link)
        default:
            Text(actionHint)
                .font(.caption)
                .foregroundStyle(DiaryDesign.secondaryText)
        }
    }

    private var readinessStrip: some View {
        VStack(spacing: 0) {
            readinessRow(
                symbol: model.vaultPath == nil ? "folder.badge.questionmark" : "folder.badge.checkmark",
                title: model.vaultPath == nil ? "Connect your Obsidian vault" : "Diary folder connected",
                detail: model.vaultPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Creates and appends under Diary/",
                ready: model.vaultPath != nil
            ) {
                if model.vaultPath == nil {
                    Button("Choose…") { Task { await model.chooseVault() } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            Hairline().padding(.leading, 44)
            readinessRow(
                symbol: model.modelState.isUsable ? "cpu.fill" : "square.and.arrow.down",
                title: model.modelState.isUsable ? "Local model installed" : "Install transcription model",
                detail: modelDetail,
                ready: model.modelState.isUsable
            ) {
                if case .downloading = model.modelState {
                    ProgressView(value: modelProgress).frame(width: 76)
                } else if !model.modelState.isUsable {
                    Button("Install…") { Task { await model.installModel() } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private func readinessRow<Accessory: View>(
        symbol: String,
        title: String,
        detail: String,
        ready: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 16)
                .foregroundStyle(ready ? DiaryDesign.signal : DiaryDesign.secondaryText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption).foregroundStyle(DiaryDesign.secondaryText).lineLimit(1)
            }
            Spacer()
            accessory()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private var footer: some View {
        HStack(spacing: 15) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showsWriting.toggle() }
            } label: {
                Label(showsWriting ? "Hide writing" : "Write instead", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DiaryDesign.secondaryText)

            Spacer()
            SettingsLink {
                Image(systemName: "gearshape").accessibilityLabel("Settings")
            }
            .buttonStyle(.plain).foregroundStyle(DiaryDesign.secondaryText)
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").accessibilityLabel("Quit Diary Transcription")
            }
            .buttonStyle(.plain).foregroundStyle(DiaryDesign.secondaryText)
            .disabled(capture.isRecording || model.workflowState.isBusy)
            .help(
                capture.isRecording || model.workflowState.isBusy
                    ? "Finish the current recording before quitting"
                    : "Quit Diary Transcription"
            )
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var captureTitle: String {
        switch model.workflowState {
        case .transcribing: return "Turning speech into text"
        case .saving: return "Saving your entry"
        case .saved: return "Added to today’s diary"
        case .failed where model.hasPendingRecording: return "Your recording is safe"
        default: break
        }
        if model.vaultPath == nil, capture.phase == .idle { return "Connect your vault" }
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
        case .saving: return "The Markdown append is coordinated so existing notes are preserved."
        case let .saved(_, preview): return preview
        case let .failed(message): return message
        default: break
        }
        if model.vaultPath == nil, capture.phase == .idle {
            return "Choose the folder that contains your Obsidian vault."
        }
        if !model.modelState.isUsable, capture.phase == .idle {
            return "Install the one-time 2.42 GB INT8 model. It works offline afterward."
        }
        return switch capture.phase {
        case .idle: "Speak naturally. The signal below responds to microphone input."
        case .requestingPermission: "macOS may ask for permission once."
        case .recording: "The model is warming while your audio stays on this Mac."
        case .captured: "Ready to retry local transcription."
        case let .interrupted(message): message
        case .permissionDenied: "Allow Diary Transcription in Privacy & Security, then try again."
        case let .failed(message): message
        }
    }

    private var isProcessing: Bool { model.workflowState.isBusy }
    private var recordButtonDisabled: Bool {
        if capture.isRecording { return false }
        return !model.canRecord || capture.phase == .requestingPermission || isProcessing
    }

    private var recordButtonHint: String {
        if capture.isRecording { return "Stops, transcribes, and appends the entry" }
        if model.vaultPath == nil { return "Choose an Obsidian vault first" }
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
                ?? "Press the microphone to begin. Add a shortcut in Settings if you want one."
        }
        return "Complete the setup below to begin."
    }

    private var modelProgress: Double {
        if case let .downloading(value) = model.modelState { return value }
        return 0
    }

    private var modelDetail: String {
        switch model.modelState {
        case .notInstalled: "2.42 GB · INT8 · first download only"
        case let .downloading(value): "Downloading · \(Int(value * 100))%"
        case .installed: "2.42 GB · loads when recording starts"
        case .loading: "Loading into memory…"
        case .ready: "Ready offline · kept warm between entries"
        case let .failed(message): message
        }
    }

    private func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct DiarySettingsView: View {
    @Bindable var model: DiaryAppModel
    @State private var confirmsModelRemoval = false

    var body: some View {
        Form {
            Section("Obsidian Vault") {
                LabeledContent("Vault") {
                    Text(model.vaultPath ?? "No vault selected")
                        .font(.callout.monospaced()).textSelection(.enabled).lineLimit(2)
                }
                HStack {
                    Button("Choose Existing Vault…") { Task { await model.chooseVault() } }
                    Button("Open Today’s Diary") { Task { await model.openTodayDiary() } }
                        .disabled(model.vaultPath == nil)
                }
                Text("Voice and manual entries are appended to Diary/diary-log_YYYY-MM-DD.md. Existing text is never replaced.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Local Transcription") {
                modelInstallationRow
                Picker("Recording language", selection: $model.languageCode) {
                    ForEach(DiaryAppModel.languages) { language in
                        Text(language.name).tag(language.id)
                    }
                }
                Text("Cohere Transcribe 2B INT8 runs locally through Apple MLX. The model is about 2.42 GB and needs the internet only for installation.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Global Shortcut") {
                LabeledContent("Record / stop") {
                    ShortcutRecorder(binding: Binding(
                        get: { model.shortcut },
                        set: { model.setShortcut($0) }
                    ))
                    .frame(width: 250, height: 34)
                }
                Text("No shortcut is set by default. Click the field, then press a shortcut with at least two modifiers. Press Delete to clear it.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = model.shortcutError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
            }

            if case let .saved(fileName, preview) = model.workflowState {
                Section("Most Recent Entry") {
                    LabeledContent(fileName) { Text(preview).lineLimit(2) }
                    Button("Open Today’s Diary") { Task { await model.openTodayDiary() } }
                }
            }

            Section("Write a Manual Entry") {
                TestEntryView(model: model)
            }

            Section("Status") { StatusView(status: model.status) }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 600, minHeight: 650)
        .confirmationDialog(
            "Remove the local transcription model?",
            isPresented: $confirmsModelRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove 2.42 GB Model", role: .destructive) {
                Task { await model.removeModel() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Diary notes and pending audio will not be removed. You will need to download the model again before transcribing.")
        }
    }

    @ViewBuilder
    private var modelInstallationRow: some View {
        switch model.modelState {
        case .notInstalled:
            HStack {
                Label("Not installed", systemImage: "square.and.arrow.down")
                Spacer()
                Button("Install 2.42 GB Model") { Task { await model.installModel() } }
                    .buttonStyle(.borderedProminent)
            }
        case let .downloading(value):
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text("Downloading INT8 model…"); Spacer(); Text("\(Int(value * 100))%") }
                ProgressView(value: value)
            }
        case .installed, .ready:
            HStack {
                Label("Installed and available offline", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Remove Model", role: .destructive) { confirmsModelRemoval = true }
            }
        case .loading:
            HStack { ProgressView().controlSize(.small); Text("Loading model…") }
        case let .failed(message):
            VStack(alignment: .leading, spacing: 7) {
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Button("Try Installation Again") { Task { await model.installModel() } }
            }
        }
    }
}
