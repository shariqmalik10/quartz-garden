import SwiftUI

struct DiarySettingsView: View {
  @Bindable var model: DiaryAppModel
  @State private var selectedTab = SettingsTab.vault

  private enum SettingsTab: Hashable {
    case vault
    case appearance
    case shortcut
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      VaultSettingsTab(model: model)
        .tabItem { Label("Vault & Model", systemImage: "externaldrive") }
        .tag(SettingsTab.vault)
      AppearanceSettingsTab(model: model)
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
        .tag(SettingsTab.appearance)
      ShortcutSettingsTab(model: model)
        .tabItem { Label("Shortcut", systemImage: "keyboard") }
        .tag(SettingsTab.shortcut)
    }
    .padding(14)
    .frame(minWidth: 640, minHeight: 560)
  }
}

private struct VaultSettingsTab: View {
  @Bindable var model: DiaryAppModel
  @State private var confirmsModelRemoval = false

  var body: some View {
    Form {
      Section("Obsidian Vault") {
        LabeledContent("Vault") {
          Text(model.vaultPath ?? "No vault selected")
            .font(.callout.monospaced())
            .textSelection(.enabled)
            .lineLimit(2)
        }
        HStack {
          Button("Choose Existing Vault…") { Task { await model.chooseVault() } }
          Button("Open Today in Obsidian") { Task { await model.openTodayDiary() } }
            .disabled(model.vaultPath == nil)
        }
      }

      Section("Where entries go") {
        LabeledContent("Private daily capture", value: "Diary/diary-log_YYYY-MM-DD.md")
        LabeledContent("Private blog drafts", value: "Writing/Blogs/<your-title>.md")
        LabeledContent("Study and working notes", value: "Notes/<your-title>.md")
        LabeledContent("Any existing Markdown", value: "Any .md file inside the vault")
        Text(
          "The destination studio remembers recent files. New blogs start private; publishing remains an explicit metadata change in Obsidian."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Local Transcription") {
        modelInstallationRow
        Picker("Recording language", selection: $model.languageCode) {
          ForEach(DiaryAppModel.languages) { language in
            Text(language.name).tag(language.id)
          }
        }
        Text(
          "Cohere Transcribe 2B INT8 runs locally through Apple MLX. The model is about 2.42 GB and needs the internet only for installation."
        )
        .font(.caption).foregroundStyle(.secondary)
      }

      Section("Status") { StatusView(status: model.status) }
    }
    .formStyle(.grouped)
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
      Text(
        "Diary notes and pending audio will not be removed. You will need to download the model again before transcribing."
      )
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
    case .downloading(let value):
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("Downloading INT8 model…")
          Spacer()
          Text("\(Int(value * 100))%")
        }
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
      HStack {
        ProgressView().controlSize(.small)
        Text("Loading model…")
      }
    case .failed(let message):
      VStack(alignment: .leading, spacing: 7) {
        Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        Button("Try Installation Again") { Task { await model.installModel() } }
      }
    }
  }
}

private struct AppearanceSettingsTab: View {
  @Bindable var model: DiaryAppModel

  var body: some View {
    Form {
      Section("Theme") {
        Picker("Color theme", selection: $model.themeChoice) {
          ForEach(DiaryThemeChoice.allCases) { theme in
            Text(theme.name).tag(theme)
          }
        }
        .pickerStyle(.radioGroup)
        Text(model.themeChoice.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
        themeSwatches
      }

      Section("Sound capture") {
        visualizationPicker
        AudioVisualizationView(
          capture: model.capture,
          style: model.visualizationStyle
        )
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(model.themeChoice.palette.field)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .environment(\.diaryPalette, model.themeChoice.palette)
        Text(
          "The visualization moves only when microphone input is present. Reduced Motion is respected."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }

  private var themeSwatches: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
      spacing: 8
    ) {
      ForEach(DiaryThemeChoice.allCases) { theme in
        let colors = theme.palette
        Button {
          model.themeChoice = theme
        } label: {
          VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 0) {
              Rectangle().fill(colors.canvas)
              Rectangle().fill(colors.signal)
              Rectangle().fill(colors.record)
            }
            .frame(height: 25)
            Text(theme.name)
              .font(.caption2.weight(.medium))
              .foregroundStyle(.primary)
              .lineLimit(1)
          }
          .padding(5)
          .frame(maxWidth: .infinity, alignment: .leading)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(
                model.themeChoice == theme ? Color.accentColor : Color.secondary.opacity(0.25),
                lineWidth: model.themeChoice == theme ? 2 : 1
              )
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
      }
    }
  }

  private var visualizationPicker: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
      spacing: 8
    ) {
      ForEach(CaptureVisualizationStyle.allCases) { style in
        Button {
          model.visualizationStyle = style
        } label: {
          VStack(spacing: 6) {
            Image(systemName: style.symbolName)
              .font(.system(size: 16, weight: .semibold))
            Text(style.name)
              .font(.caption2.weight(.medium))
              .lineLimit(1)
          }
          .foregroundStyle(
            model.visualizationStyle == style
              ? model.themeChoice.palette.controlInk
              : model.themeChoice.palette.text
          )
          .frame(maxWidth: .infinity)
          .padding(.vertical, 9)
          .background(
            model.visualizationStyle == style
              ? model.themeChoice.palette.signal
              : model.themeChoice.palette.elevated
          )
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.visualizationStyle == style ? .isSelected : [])
      }
    }
    .environment(\.diaryPalette, model.themeChoice.palette)
  }
}

private struct ShortcutSettingsTab: View {
  @Bindable var model: DiaryAppModel

  var body: some View {
    Form {
      Section("Global record / stop shortcut") {
        LabeledContent("Shortcut") {
          ShortcutRecorder(
            binding: Binding(
              get: { model.shortcut },
              set: { model.setShortcut($0) }
            )
          )
          .frame(width: 250, height: 34)
        }
        Text(
          "No shortcut is set by default. Click the field, then press a shortcut with at least two modifiers. Press Delete to clear it."
        )
        .font(.caption).foregroundStyle(.secondary)
        if let error = model.shortcutError {
          Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(.red)
        }
      }

      Section("Privacy") {
        Label(
          "Audio stays in Application Support until its Markdown append succeeds.",
          systemImage: "lock.fill")
        Label("Transcription runs locally after the model’s one-time download.", systemImage: "cpu")
        Label(
          "No keyboard shortcut is active unless you choose one.",
          systemImage: "keyboard.badge.ellipsis")
      }
    }
    .formStyle(.grouped)
  }
}
