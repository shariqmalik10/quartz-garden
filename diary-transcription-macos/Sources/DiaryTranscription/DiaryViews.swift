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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test entry").font(.headline)
            TextEditor(text: $model.testEntry)
                .font(.body)
                .frame(minHeight: 90)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                }
                .accessibilityLabel("Diary test entry")
            Button {
                Task { await model.saveTestEntry() }
            } label: {
                if model.isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Append to Today’s Diary", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isSaving || model.testEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct MenuBarContentView: View {
    @Bindable var model: DiaryAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusView(status: model.status)
            Divider()
            TestEntryView(model: model)
            Divider()
            HStack {
                SettingsLink {
                    Label("Settings…", systemImage: "gear")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
        .task { await model.restoreVault() }
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

            Section("Safe Write Test") {
                TestEntryView(model: model)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 520, minHeight: 460)
    }
}
