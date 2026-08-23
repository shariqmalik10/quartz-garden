import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NotchComposerView: View {
    @ObservedObject private var model: CaptureComposerModel

    let safeTopInset: CGFloat
    let onSettings: () -> Void
    let onClose: () -> Void
    let onCaptureStatusChanged: (CaptureComposerStatus) -> Void

    private enum FocusTarget: Hashable {
        case source
        case thought
    }

    @FocusState private var focusedField: FocusTarget?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDropTargeted = false
    @State private var isShowingDiscardConfirmation = false
    @State private var doneDismissWorkItem: DispatchWorkItem?
    @State private var savingIndicatorWorkItem: DispatchWorkItem?
    @State private var isSavingIndicatorActive = false

    init(
        model: CaptureComposerModel,
        safeTopInset: CGFloat,
        onSettings: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onCaptureStatusChanged: @escaping (CaptureComposerStatus) -> Void
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.safeTopInset = safeTopInset
        self.onSettings = onSettings
        self.onClose = onClose
        self.onCaptureStatusChanged = onCaptureStatusChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: safeTopInset)

            composerContent
        }
        .frame(
            width: NotchComposerPanelLayout.composerSize.width,
            height: panelSize.height,
            alignment: .top
        )
        .onAppear {
            scheduleInitialFocus()
        }
        .onDisappear {
            doneDismissWorkItem?.cancel()
        }
        .onExitCommand(perform: requestClose)
        .onChange(of: model.state) { _, newState in
            onCaptureStatusChanged(newState.compatibilityStatus)
            handleStateChange(newState)
        }
        .confirmationDialog(
            "Discard this capture?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard Draft", role: .destructive) {
                guard !model.isSaving else {
                    return
                }
                onClose()
            }
        } message: {
            Text("Your changes have not been planted yet.")
        }
        .accessibilityElement(children: .contain)
    }

    private var composerContent: some View {
        VStack(spacing: 0) {
            header

            sourceDropRow
                .padding(.horizontal, 14)
                .padding(.top, 8)

            thoughtSection
                .padding(.top, 8)

            destinationRow
                .padding(.top, 8)

            statusSection
                .padding(.top, 8)

            saveButton
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .frame(
            width: NotchComposerPanelLayout.composerSize.width,
            height: panelSize.height - safeTopInset,
            alignment: .top
        )
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 8) {
            stateIndicator

            Text("New capture")
                .font(NotchTypography.font(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(1)

            Spacer(minLength: 8)

            moreMenu

            Button(action: requestClose) {
                Image(systemName: "xmark")
                    .font(NotchTypography.font(11, weight: .bold))
                    .foregroundStyle(.white.opacity(model.isSaving ? 0.22 : 0.58))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isSaving)
            .help(model.isSaving ? "Capture is saving" : "Close capture surface")
            .accessibilityLabel("Close capture surface")
            .accessibilityHint(
                model.hasUnsavedChanges
                    ? "Asks for confirmation before discarding changes"
                    : "Closes the capture surface"
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private var stateIndicator: some View {
        ZStack {
            Circle()
                .fill(stateIndicatorFill)

            stateMark
                .id(stateKey)
                .transition(.opacity)
        }
        .frame(width: 18, height: 18)
        .animation(feedbackAnimation, value: stateKey)
        .accessibilityLabel("Capture state: \(stateTitle)")
        .onAppear {
            synchronizeSavingIndicator(for: model.state)
        }
        .onChange(of: model.state) { _, newState in
            synchronizeSavingIndicator(for: newState)
        }
        .onChange(of: reduceMotion) { _, _ in
            synchronizeSavingIndicator(for: model.state)
        }
        .onDisappear {
            stopSavingIndicator()
        }
    }

    @ViewBuilder
    private var stateMark: some View {
        switch model.state {
        case .empty, .prepared:
            Circle()
                .strokeBorder(Color.white.opacity(0.70), lineWidth: 1.4)
                .frame(width: 6, height: 6)
        case .saving:
            Circle()
                .trim(from: 0.08, to: 0.82)
                .stroke(
                    gardenRust.opacity(0.92),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(isSavingIndicatorActive && !reduceMotion ? 360 : 0))
                .animation(
                    reduceMotion
                        ? nil
                        : .linear(duration: 0.90).repeatForever(autoreverses: false),
                    value: isSavingIndicatorActive
                )
        case .done:
            Image(systemName: "checkmark")
                .font(NotchTypography.font(9, weight: .bold))
                .foregroundStyle(.white)
        case .error:
            Image(systemName: "exclamationmark")
                .font(NotchTypography.font(9, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var sourceDropRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isDropTargeted ? "arrow.down.circle" : sourceSymbol)
                .font(NotchTypography.font(17, weight: .medium))
                .foregroundStyle(isDropTargeted ? gardenRust : .white.opacity(0.62))
                .frame(width: 24)
                .accessibilityHidden(true)

            if isDropTargeted {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Release to add")
                        .font(NotchTypography.font(13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    Text("File, link, or text")
                        .font(NotchTypography.font(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
            } else if model.hasSource {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.activeSource.title)
                        .font(NotchTypography.font(13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(sourceDetail)
                        .font(NotchTypography.font(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source")
                        .font(NotchTypography.font(11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.54))

                    TextField("Paste a link or add text", text: $model.draftInput)
                        .textFieldStyle(.plain)
                        .font(NotchTypography.font(13))
                        .foregroundStyle(.white.opacity(0.92))
                        .focused($focusedField, equals: .source)
                        .onSubmit(commitSourceInput)
                        .accessibilityLabel("Source link or text")
                        .accessibilityHint("Paste a URL or type text to add to this capture")
                }
            }

            Spacer(minLength: 8)

            if model.hasSource && !isDropTargeted {
                Image(systemName: "checkmark.circle.fill")
                    .font(NotchTypography.font(13, weight: .medium))
                    .foregroundStyle(gardenLeaf)
                    .accessibilityHidden(true)
            } else if !isDropTargeted {
                Image(systemName: "arrow.down.to.line")
                    .font(NotchTypography.font(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.34))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
        .background(isDropTargeted ? gardenRust.opacity(0.12) : Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? gardenRust.opacity(0.82) : Color.white.opacity(0.11),
                    lineWidth: isDropTargeted ? 1.25 : 1
                )
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onDrop(
            of: [
                UTType.fileURL.identifier,
                UTType.url.identifier,
                UTType.text.identifier,
            ],
            isTargeted: $isDropTargeted,
            perform: handleDrop
        )
        .animation(feedbackAnimation, value: isDropTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(sourceAccessibilityLabel)
        .disabled(model.isSaving)
    }

    private var thoughtSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Thought")
                .font(NotchTypography.font(11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.thought)
                    .font(NotchTypography.font(13))
                    .foregroundStyle(.white.opacity(0.92))
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .focused($focusedField, equals: .thought)
                    .disabled(model.isSaving)

                if model.thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Why did this catch your eye?")
                        .font(NotchTypography.font(13))
                        .foregroundStyle(.white.opacity(0.30))
                        .padding(.leading, 11)
                        .padding(.top, 11)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        focusedField == .thought
                            ? gardenRust.opacity(0.72)
                            : Color.white.opacity(0.10),
                        lineWidth: focusedField == .thought ? 1.25 : 1
                    )
                    .allowsHitTesting(false)
            }
            .animation(feedbackAnimation, value: focusedField == .thought)
            .accessibilityLabel("Thought")
            .accessibilityHint("Optional context for this capture")
        }
        .padding(.horizontal, 14)
    }

    private var destinationRow: some View {
        Menu {
            Section("Quick destinations") {
                ForEach(model.destinationStore.favorites) { destination in
                    destinationButton(destination)
                }
            }

            let extraDestinations = model.destinationStore.allDestinations.filter {
                !model.destinationStore.favorites.contains($0)
            }
            if !extraDestinations.isEmpty {
                Section("Saved destinations") {
                    ForEach(extraDestinations) { destination in
                        destinationButton(destination)
                    }
                }
            }

            Divider()

            Button {
                chooseDestination(.folder)
            } label: {
                Label("Choose folder…", systemImage: "folder.badge.plus")
            }

            Button {
                chooseDestination(.markdownFile)
            } label: {
                Label("Choose Markdown file…", systemImage: "doc.badge.plus")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.selectedDestination.kind.symbolName)
                    .font(NotchTypography.font(14, weight: .medium))
                    .foregroundStyle(model.visibility == .garden ? gardenRust : .white.opacity(0.62))
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.selectedDestination.title)
                        .font(NotchTypography.font(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)

                    Text("\(model.visibility.displayName) · \(model.selectedDestination.kind.displayName)")
                        .font(NotchTypography.font(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(NotchTypography.font(10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.36))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 14)
        .accessibilityLabel(
            "Destination: \(model.selectedDestination.title), \(model.visibility.displayName) \(model.selectedDestination.kind.displayName)"
        )
        .accessibilityHint("Choose a quick destination, folder, or Markdown file")
        .disabled(model.isSaving || !model.vaultConfiguration.isConfigured)
    }

    private func destinationButton(_ destination: CaptureDestination) -> some View {
        Button {
            model.chooseDestination(destination)
        } label: {
            Label {
                Text("\(destination.title) · \(destination.visibility.displayName)")
            } icon: {
                Image(
                    systemName: model.isSelectedDestination(destination)
                        ? "checkmark"
                        : destination.kind.symbolName
                )
            }
        }
    }

    private func chooseDestination(_ kind: CaptureDestinationKind) {
        guard model.vaultConfiguration.isConfigured else {
            return
        }
        guard let destination = DestinationPicker.choose(
            kind: kind,
            vaultRoot: model.vaultConfiguration.rootURL
        ) else {
            return
        }
        model.chooseDestination(destination)
    }

    private var statusSection: some View {
        statusView
            .frame(maxWidth: .infinity, minHeight: statusHeight, maxHeight: statusHeight, alignment: .topLeading)
            .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.state {
        case .empty:
            if model.vaultConfiguration.isConfigured {
                statusLabel("Add a source or thought to plant", systemImage: "arrow.down.circle")
            } else {
                statusLabel("Choose a vault in Settings before saving", systemImage: "externaldrive.badge.plus")
            }
        case .prepared:
            if model.vaultConfiguration.isConfigured {
                statusLabel("Ready to plant locally", systemImage: "externaldrive")
            } else {
                statusLabel("Choose a vault in Settings before saving", systemImage: "externaldrive.badge.plus")
            }
        case .saving:
            statusLabel("Saving locally…", systemImage: "arrow.down.circle")
        case .done:
            statusLabel("Saved to \(model.visibility.displayName)", systemImage: "checkmark.circle.fill", color: gardenLeaf)
        case .error(let message):
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle")
                    .font(NotchTypography.font(11, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.92))
                    .frame(width: 15)

                Text(message)
                    .font(NotchTypography.font(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Capture error: \(message)")
        }
    }

    private func statusLabel(
        _ title: String,
        systemImage: String,
        color: Color? = nil
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(NotchTypography.font(11, weight: .medium))
            .foregroundStyle(color ?? .white.opacity(0.48))
            .lineLimit(1)
            .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        Button(action: saveCapture) {
            HStack(spacing: 8) {
                Image(systemName: saveSymbol)
                    .font(NotchTypography.font(12, weight: .semibold))

                Text(saveTitle)
                    .font(NotchTypography.font(13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(saveButtonIsEnabled ? 0.96 : 0.42))
            .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
            .background(saveButtonFill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(saveButtonIsEnabled ? 0.08 : 0.05), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!saveButtonIsEnabled)
        .padding(.horizontal, 14)
        .accessibilityLabel(saveTitle)
        .accessibilityHint("Press Command-Return to save")
        .help("\(saveTitle) (⌘Return)")
    }

    private var moreMenu: some View {
        Menu {
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button {
                model.clearCapture()
            } label: {
                Label("Clear draft", systemImage: "trash")
            }
            .disabled(model.isSaving)

            Button {
                NSWorkspace.shared.open(model.vaultConfiguration.rootURL)
            } label: {
                Label("Open vault", systemImage: "externaldrive")
            }
            .disabled(!model.vaultConfiguration.isConfigured)
        } label: {
            Image(systemName: "ellipsis")
                .font(NotchTypography.font(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("More capture options")
        .accessibilityLabel("More capture options")
    }

    private var panelSize: CGSize {
        model.state.errorMessage == nil
            ? NotchComposerPanelLayout.composerSize
            : NotchComposerPanelLayout.errorSize
    }

    private var statusHeight: CGFloat {
        model.state.errorMessage == nil ? 28 : 64
    }

    private var stateIndicatorFill: Color {
        switch model.state {
        case .done:
            return gardenLeaf
        case .error:
            return Color.red.opacity(0.72)
        case .saving:
            return gardenRust.opacity(0.18)
        case .empty, .prepared:
            return Color.white.opacity(0.10)
        }
    }

    private var stateTitle: String {
        switch model.state {
        case .empty:
            return "Empty"
        case .prepared:
            return "Ready to plant"
        case .saving:
            return "Saving"
        case .done:
            return "Saved"
        case .error:
            return "Error"
        }
    }

    private var stateKey: String {
        switch model.state {
        case .empty:
            return "empty"
        case .prepared:
            return "prepared"
        case .saving:
            return "saving"
        case .done:
            return "done"
        case .error(let message):
            return "error:\(message)"
        }
    }

    private var saveButtonIsEnabled: Bool {
        model.vaultConfiguration.isConfigured && !model.isSaving && model.canPlant && !isDone
    }

    private var isDone: Bool {
        if case .done = model.state {
            return true
        }
        return false
    }

    private var saveTitle: String {
        switch model.state {
        case .saving:
            return "Saving…"
        case .done:
            return "Saved to \(model.visibility.displayName)"
        default:
            return model.vaultConfiguration.isConfigured
                ? model.visibility.actionTitle
                : "Choose vault in Settings"
        }
    }

    private var saveSymbol: String {
        switch model.state {
        case .saving:
            return "arrow.down.circle"
        case .done:
            return "checkmark"
        default:
            return model.vaultConfiguration.isConfigured
                ? model.visibility.symbolName
                : "externaldrive.badge.plus"
        }
    }

    private var saveButtonFill: Color {
        if isDone {
            return gardenLeaf
        }
        if model.isSaving {
            return gardenRust.opacity(0.64)
        }
        return saveButtonIsEnabled ? gardenRust : Color.white.opacity(0.10)
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

    private var sourceDetail: String {
        if let domain = model.activeSource.domain, !domain.isEmpty {
            return "\(domain) · \(model.activeSource.type.displayName)"
        }
        if let attachment = model.droppedAttachment {
            return "File · \(attachment.fileName)"
        }
        if let capturedText = model.activeSource.capturedText,
           !capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return capturedText
        }
        return model.activeSource.type.displayName
    }

    private var sourceAccessibilityLabel: String {
        if isDropTargeted {
            return "Drop target. Release a file, link, or text to add it."
        }
        if model.hasSource {
            return "Source: \(model.activeSource.title), \(sourceDetail)"
        }
        return "Source input. Paste a link or add text."
    }

    private var feedbackAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16)
    }

    private func synchronizeSavingIndicator(for state: CaptureComposerState) {
        savingIndicatorWorkItem?.cancel()
        savingIndicatorWorkItem = nil
        isSavingIndicatorActive = false

        guard state == .saving, !reduceMotion else {
            return
        }

        let shouldReduceMotion = reduceMotion
        let workItem = DispatchWorkItem { [model] in
            guard model.isSaving, !shouldReduceMotion else {
                return
            }
            isSavingIndicatorActive = true
        }
        savingIndicatorWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func stopSavingIndicator() {
        savingIndicatorWorkItem?.cancel()
        savingIndicatorWorkItem = nil
        isSavingIndicatorActive = false
    }

    private func scheduleInitialFocus() {
        let target: FocusTarget = model.initialFocusTarget == .source ? .source : .thought
        let delay: TimeInterval = reduceMotion ? 0.14 : 0.30

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard focusedField == nil else {
                return
            }
            focusedField = target
        }
    }

    private func handleStateChange(_ newState: CaptureComposerState) {
        switch newState {
        case .done:
            scheduleDoneDismissal()
        default:
            doneDismissWorkItem?.cancel()
            doneDismissWorkItem = nil
        }
    }

    private func scheduleDoneDismissal() {
        doneDismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [model, onClose] in
            guard case .done = model.state else {
                return
            }
            onClose()
        }
        doneDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.25,
            execute: workItem
        )
    }

    private func requestClose() {
        guard !model.isSaving else {
            return
        }

        if model.hasUnsavedChanges {
            isShowingDiscardConfirmation = true
        } else {
            onClose()
        }
    }

    private func commitSourceInput() {
        guard model.hasPendingInput else {
            return
        }

        model.commitDraftInput()
        focusedField = .thought
    }

    private func saveCapture() {
        guard !model.isSaving else {
            return
        }

        model.commitDraftInput()
        model.save()
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
                        focusedField = .thought
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
                        focusedField = .thought
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
                        focusedField = .thought
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
