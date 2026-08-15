import AppKit
import SwiftUI

struct CaptureComposerView: View {
    @StateObject private var model: CaptureComposerModel

    init(model: CaptureComposerModel = CaptureComposerModel()) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.top, 12)

            sourcePreview
                .padding(.top, 14)

            linkField
                .padding(.bottom, 14)

            Divider()

            thoughtField
                .padding(.vertical, 14)

            areaSelector

            Divider()
                .padding(.top, 14)

            footer
                .padding(.top, 12)
        }
        .padding(14)
        .frame(width: 420, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(gardenRust)

            Text("Garden Drop")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Text("Local capture")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var sourcePreview: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: sourceSymbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(gardenRust)
                .frame(width: 56, height: 56)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.activeSource.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Text(sourceMetadata)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if let excerpt = model.source.excerpt {
                    Text(excerpt)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Button(action: {}) {
                Image(systemName: "arrow.up.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Open original")
            .accessibilityLabel("Open original")
        }
        .accessibilityElement(children: .combine)
    }

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Link to capture (optional)")
                .font(.system(size: 13, weight: .medium))

            TextField("https://…", text: $model.linkText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .accessibilityLabel("Link to capture")

            if let validationMessage = model.linkValidationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thoughtField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why did this catch your eye?")
                .font(.system(size: 13, weight: .medium))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.thought)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(5)
                    .frame(minHeight: 44, maxHeight: 96)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if model.thought.isEmpty {
                    Text("Add a thought…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 10)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var areaSelector: some View {
        Menu {
            ForEach(AreaOption.defaults) { area in
                Button {
                    model.selectedArea = area
                } label: {
                    Label {
                        Text("\(area.name) · \(area.visibility.displayName)")
                    } icon: {
                        Image(systemName: area.visibility.symbolName)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.visibility.symbolName)
                    .foregroundStyle(model.visibility == .garden ? gardenRust : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selectedArea.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(model.visibility.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("\(model.selectedArea.name), \(model.visibility.displayName) area")
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            statusView

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    model.save()
                } label: {
                    Label(model.visibility.actionTitle, systemImage: model.visibility.symbolName)
                }
                .buttonStyle(.borderedProminent)
                .tint(gardenRust)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isSaving || !model.canPlant)

                Text("⌘Return to save")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            Label(model.vaultLabel, systemImage: "externaldrive")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .saving:
            Label("Saving…", systemImage: "arrow.down.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .saved:
            Label("Saved locally", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(gardenLeaf)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(3)
        }
    }

    private var sourceSymbol: String {
        switch model.activeSource.type {
        case .web:
            return "link"
        case .image:
            return "photo"
        case .text:
            return "text.quote"
        }
    }

    private var sourceMetadata: String {
        let domain = model.activeSource.domain ?? model.activeSource.type.displayName
        return "\(domain) · \(model.activeSource.type.displayName)"
    }

    private var gardenRust: Color {
        Color(red: 0.741, green: 0.329, blue: 0.220)
    }

    private var gardenLeaf: Color {
        Color(red: 0.325, green: 0.427, blue: 0.349)
    }
}
