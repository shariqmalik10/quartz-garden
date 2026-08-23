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
            if !compact {
                Text("Write instead").font(.headline)
            }
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
                    || model.vaultPath == nil
                    || model.testEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            if compact {
                StatusView(status: model.status)
                    .padding(.top, 2)
            }
        }
    }
}

/*
THESIS: A private listening field makes voice capture feel calm, local, and trustworthy.
OWN-WORLD: Deep graphite, warm white, sea-glass signal, and coral only for record/stop.
STORY: Confirm the microphone can hear you, stop with confidence, then retain the audio safely.
FIRST VIEWPORT: Listening state, real waveform, duration, and one primary capture action.
FORM: Native macOS Operate surface extending the existing menu-bar utility.
*/
struct MenuBarContentView: View {
    @Bindable var model: DiaryAppModel
    @Bindable var capture: AudioCaptureModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWriting = false

    var body: some View {
        VStack(spacing: 0) {
            header
            captureField
            vaultStrip

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
        .frame(width: 392)
        .task { await model.restoreVault() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Diary")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Private capture · on this Mac")
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

            captureActions
                .frame(minHeight: 24)
        }
        .padding(.horizontal, 18)
        .padding(.top, 17)
        .padding(.bottom, 16)
        .background(DiaryDesign.field)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var recordControl: some View {
        Button {
            Task { await capture.primaryAction() }
        } label: {
            ZStack {
                Circle()
                    .fill(capture.isRecording ? DiaryDesign.record.opacity(0.18) : DiaryDesign.record)
                    .frame(width: 66, height: 66)
                if capture.isRecording {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DiaryDesign.record)
                        .frame(width: 24, height: 24)
                } else if capture.phase == .requestingPermission {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DiaryDesign.canvas)
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
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .accessibilityLabel(capture.isRecording ? "Stop recording" : "Start recording")
        .accessibilityHint(recordButtonHint)
    }

    @ViewBuilder
    private var captureActions: some View {
        switch capture.phase {
        case .captured, .interrupted:
            HStack(spacing: 14) {
                Button("Show file") {
                    if let url = capture.capturedURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                Button("Discard", role: .destructive) {
                    capture.discardRecording()
                }
            }
            .buttonStyle(.link)
        case .permissionDenied:
            HStack(spacing: 14) {
                Button("Open Privacy Settings") { openMicrophoneSettings() }
                Button("Try again") { capture.resetPermissionState() }
            }
            .buttonStyle(.link)
        default:
            Text(recordButtonDisabled && model.vaultPath == nil
                 ? "Choose your vault before the first recording."
                 : capture.isRecording ? "Press ⌘⇧R or the stop button when you’re done." : "Press ⌘⇧R to begin.")
                .font(.caption)
                .foregroundStyle(DiaryDesign.secondaryText)
        }
    }

    private var vaultStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: model.vaultPath == nil ? "folder.badge.questionmark" : "folder.badge.checkmark")
                .foregroundStyle(model.vaultPath == nil ? DiaryDesign.secondaryText : DiaryDesign.signal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.vaultPath == nil ? "Connect your Obsidian vault" : "Diary folder connected")
                    .font(.callout.weight(.medium))
                Text(model.vaultPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Audio and notes remain under your control.")
                    .font(.caption)
                    .foregroundStyle(DiaryDesign.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if model.vaultPath == nil {
                Button("Choose…") { Task { await model.chooseVault() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var footer: some View {
        HStack(spacing: 15) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    showsWriting.toggle()
                }
            } label: {
                Label(showsWriting ? "Hide writing" : "Write instead", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DiaryDesign.secondaryText)

            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DiaryDesign.secondaryText)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .accessibilityLabel("Quit Diary Transcription")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DiaryDesign.secondaryText)
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var captureTitle: String {
        if model.vaultPath == nil, capture.phase == .idle {
            return "Connect your vault"
        }
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
        if model.vaultPath == nil, capture.phase == .idle {
            return "Choose your Obsidian vault before the first recording."
        }
        return switch capture.phase {
        case .idle: "Speak naturally. The signal below responds to microphone input."
        case .requestingPermission: "macOS may ask for permission once."
        case .recording: "Your audio is being recorded on this Mac."
        case .captured: "Ready for the local transcription model in the next milestone."
        case let .interrupted(message): message
        case .permissionDenied: "Allow Diary Transcription in Privacy & Security, then try again."
        case let .failed(message): message
        }
    }

    private var recordButtonDisabled: Bool {
        model.vaultPath == nil
            || capture.phase == .requestingPermission
            || capture.phase == .captured
            || isInterrupted
    }

    private var recordButtonHint: String {
        if model.vaultPath == nil { return "Choose an Obsidian vault first" }
        if capture.phase == .captured || isInterrupted {
            return "Discard the pending recording before starting another"
        }
        return capture.isRecording ? "Stops and retains the local audio file" : "Begins local microphone capture"
    }

    private var isInterrupted: Bool {
        if case .interrupted = capture.phase { return true }
        return false
    }

    private func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct DiarySettingsView: View {
    @Bindable var model: DiaryAppModel

    var body: some View {
        Form {
            Section("Obsidian Vault") {
                if let vaultPath = model.vaultPath {
                    Text(vaultPath)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text("No vault selected").foregroundStyle(.secondary)
                }
                Button("Choose Existing Vault…") {
                    Task { await model.chooseVault() }
                }
            }

            Section("Filesystem Status") {
                StatusView(status: model.status)
            }

            Section("Write a Manual Entry") {
                TestEntryView(model: model)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 520, minHeight: 460)
    }
}
