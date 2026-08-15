import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum NotchComposerLayout {
    static let size = CGSize(width: 340, height: 500)
}

struct NotchComposerView: View {
    @ObservedObject private var model: CaptureComposerModel

    let safeTopInset: CGFloat
    let onSettings: () -> Void
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var isDropTargeted = false
    @State private var inputMode: NotchInputMode = .anything
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        model: CaptureComposerModel,
        safeTopInset: CGFloat,
        onSettings: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.safeTopInset = safeTopInset
        self.onSettings = onSettings
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: safeTopInset)

            header
            dropZone
            footer
        }
        .frame(width: NotchComposerLayout.size.width, height: NotchComposerLayout.size.height)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isInputFocused = true
            }
        }
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 8) {
            areaMenu

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .help("Open Garden Drop settings")
            .accessibilityLabel("Open Garden Drop settings")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .help("Close capture surface")
            .accessibilityLabel("Close capture surface")
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var areaMenu: some View {
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
            HStack(spacing: 8) {
                Circle()
                    .fill(model.visibility == .garden ? gardenRust : Color.white.opacity(0.52))
                    .frame(width: 7, height: 7)

                Text(model.selectedArea.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Capture area: \(model.selectedArea.name)")
    }

    private var dropZone: some View {
        ZStack(alignment: .bottom) {
            NotchDotGrid(isHighlighted: isDropTargeted)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                Spacer(minLength: 34)

                Image(systemName: model.droppedAttachment == nil ? "plus" : "paperclip")
                    .font(.system(size: 24, weight: .thin))
                    .foregroundStyle(.white.opacity(isDropTargeted ? 0.78 : 0.28))

                Text(dropPrompt)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(isDropTargeted ? 0.88 : 0.58))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let attachment = model.droppedAttachment {
                    Label(attachment.fileName, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(gardenLeaf)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Spacer(minLength: 58)
            }
            .padding(.horizontal, 20)

            inputBar
                .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? gardenRust.opacity(0.9) : Color.white.opacity(0.16),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
        .onDrop(
            of: [
                UTType.fileURL.identifier,
                UTType.url.identifier,
                UTType.text.identifier,
            ],
            isTargeted: $isDropTargeted,
            perform: handleDrop
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop files or add a note")
        .animation(feedbackAnimation, value: isDropTargeted)
        .animation(feedbackAnimation, value: model.droppedAttachment?.fileName)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: inputMode.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.36))
                .frame(width: 18)

            TextField(inputMode.placeholder, text: $model.draftInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .focused($isInputFocused)
                .onTapGesture {
                    isInputFocused = true
                }
                .onSubmit {
                    model.commitDraftInput()
                }
                .accessibilityLabel(inputMode.accessibilityLabel)

            Button {
                model.commitDraftInput()
                isInputFocused = true
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(model.hasPendingInput ? .white : .white.opacity(0.28))
                    .frame(width: 24, height: 24)
                    .background(model.hasPendingInput ? gardenRust : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!model.hasPendingInput)
            .help("Add this item to the capture")
            .accessibilityLabel("Add item to capture")
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isInputFocused ? gardenRust.opacity(0.72) : Color.white.opacity(0.10),
                    lineWidth: isInputFocused ? 1.25 : 1
                )
                .allowsHitTesting(false)
        }
        .animation(feedbackAnimation, value: isInputFocused)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            statusView
                .id(statusKey)
                .transition(.opacity)
                .animation(feedbackAnimation, value: statusKey)

            Spacer(minLength: 8)

            moreMenu

            Button {
                model.commitDraftInput()
                model.save()
            } label: {
                Label("Plant", systemImage: model.visibility.symbolName)
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(gardenRust)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(model.isSaving || !model.canPlant)
            .accessibilityLabel(model.visibility.actionTitle)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            Label("Local only", systemImage: "lock.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
        case .saving:
            Label("Planting…", systemImage: "arrow.down.circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        case .saved:
            Label("Planted locally", systemImage: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(gardenLeaf)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red.opacity(0.88))
                .lineLimit(2)
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                selectInputMode(.link)
            } label: {
                Label("Add a link", systemImage: "link")
            }

            Button {
                selectInputMode(.note)
            } label: {
                Label("Add a note", systemImage: "text.quote")
            }

            Button {
                selectInputMode(.anything)
            } label: {
                Label("Automatic input", systemImage: "sparkles")
            }

            Divider()

            Button {
                model.clearCapture()
            } label: {
                Label("Clear draft", systemImage: "trash")
            }

            Button {
                NSWorkspace.shared.open(model.vaultConfiguration.rootURL)
            } label: {
                Label("Open vault", systemImage: "externaldrive")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))
                .frame(width: 30, height: 30)
        }
        .menuStyle(.borderlessButton)
        .help("More capture options")
        .accessibilityLabel("More capture options")
    }

    private var dropPrompt: String {
        if isDropTargeted {
            return "Release to add it"
        }
        if model.droppedAttachment != nil {
            return "Ready to plant"
        }
        return "Drop files or add a note below"
    }

    private var statusKey: String {
        switch model.status {
        case .idle:
            return "idle"
        case .saving:
            return "saving"
        case .saved:
            return "saved"
        case .failed(let message):
            return "failed:\(message)"
        }
    }

    private var feedbackAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16)
    }

    private func selectInputMode(_ mode: NotchInputMode) {
        inputMode = mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            isInputFocused = true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                let captureModel = model
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = Self.url(from: item) else {
                        return
                    }
                    DispatchQueue.main.async {
                        captureModel.acceptDroppedFile(url)
                    }
                }
                return true
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                let captureModel = model
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    guard let text = Self.text(from: item) else {
                        return
                    }
                    DispatchQueue.main.async {
                        captureModel.acceptDroppedText(text)
                    }
                }
                return true
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                let captureModel = model
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    guard let text = Self.text(from: item) else {
                        return
                    }
                    DispatchQueue.main.async {
                        captureModel.acceptDroppedText(text)
                    }
                }
                return true
            }
        }

        return false
    }

    nonisolated private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let url = item as? NSURL {
            return url as URL
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }

    nonisolated private static func text(from item: NSSecureCoding?) -> String? {
        if let string = item as? String {
            return string
        }
        if let string = item as? NSString {
            return string as String
        }
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        if let url = url(from: item) {
            return url.absoluteString
        }
        return nil
    }

    private var gardenRust: Color {
        Color(red: 0.741, green: 0.329, blue: 0.220)
    }

    private var gardenLeaf: Color {
        Color(red: 0.325, green: 0.427, blue: 0.349)
    }
}

private enum NotchInputMode {
    case anything
    case link
    case note

    var placeholder: String {
        switch self {
        case .anything:
            return "Add a note or link"
        case .link:
            return "Paste a link"
        case .note:
            return "Write a note"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .anything:
            return "Add a note or link"
        case .link:
            return "Paste a link"
        case .note:
            return "Write a note"
        }
    }

    var symbolName: String {
        switch self {
        case .anything:
            return "plus"
        case .link:
            return "link"
        case .note:
            return "text.quote"
        }
    }
}

private struct NotchDotGrid: View {
    let isHighlighted: Bool

    var body: some View {
        Canvas { context, size in
            let dotColor = isHighlighted
                ? Color(red: 0.82, green: 0.38, blue: 0.25).opacity(0.45)
                : Color.white.opacity(0.075)

            for y in stride(from: 14.0, through: max(14.0, size.height - 14.0), by: 24.0) {
                for x in stride(from: 14.0, through: max(14.0, size.width - 14.0), by: 24.0) {
                    let dot = Path(ellipseIn: CGRect(x: x - 1.25, y: y - 1.25, width: 2.5, height: 2.5))
                    context.fill(dot, with: .color(dotColor))
                }
            }
        }
        .background(Color.white.opacity(0.035))
    }
}
