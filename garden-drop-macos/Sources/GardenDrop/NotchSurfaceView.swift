import SwiftUI

enum NotchSurfacePhase: Equatable {
    case idle
    case peek
    case composer
}

enum NotchCaptureState: Equatable {
    case idle
    case saving
    case done

    var accessibilityDescription: String {
        switch self {
        case .idle:
            return "Ready to capture"
        case .saving:
            return "Saving capture"
        case .done:
            return "Capture saved"
        }
    }
}

enum NotchTypography {
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

@MainActor
final class NotchSurfacePresentation: ObservableObject {
    @Published private(set) var phase: NotchSurfacePhase = .idle
    @Published private(set) var composerModel: CaptureComposerModel?
    @Published private(set) var captureState: NotchCaptureState = .idle
    @Published private(set) var recentCapturePath: String?
    @Published var safeTopInset: CGFloat = 0

    func showIdle() {
        if captureState == .saving {
            captureState = .idle
        }
        phase = .idle
        composerModel = nil
    }

    func showPeek() {
        phase = .peek
        composerModel = nil
    }

    func showComposer(_ model: CaptureComposerModel) {
        if captureState == .saving {
            captureState = .idle
        }
        composerModel = model
        phase = .composer
    }

    func setCaptureState(_ state: NotchCaptureState, path: String? = nil) {
        captureState = state
        if let path {
            recentCapturePath = path
        }
    }
}

struct NotchSurfaceRootView: View {
    @ObservedObject var presentation: NotchSurfacePresentation

    let onOpen: () -> Void
    let onSettings: () -> Void
    let onClose: () -> Void
    let onCaptureStatusChanged: (CaptureComposerStatus) -> Void
    let onCaptureStateChanged: (CaptureComposerState) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            surfaceColor
                .animation(surfaceAnimation, value: presentation.phase)

            phaseContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(NotchSurfaceShape(bottomCornerRadius: cornerRadius))
        .animation(surfaceAnimation, value: presentation.phase)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch presentation.phase {
        case .idle:
            NotchIdleView()
                .transition(.opacity)

        case .peek:
            NotchPeekView(
                safeTopInset: presentation.safeTopInset,
                captureState: presentation.captureState,
                recentCapturePath: presentation.recentCapturePath,
                onOpen: onOpen,
                onSettings: onSettings
            )
            .transition(compactTransition)

        case .composer:
            if let model = presentation.composerModel {
                NotchComposerView(
                    model: model,
                    safeTopInset: presentation.safeTopInset,
                    onSettings: onSettings,
                    onClose: onClose,
                    onCaptureStatusChanged: onCaptureStatusChanged
                )
                .onChange(of: model.state) { _, newState in
                    onCaptureStateChanged(newState)
                }
                .transition(composerTransition)
            }
        }
    }

    private var surfaceColor: Color {
        presentation.phase == .composer
            ? Color(red: 0.055, green: 0.059, blue: 0.063)
            : .black
    }

    private var cornerRadius: CGFloat {
        presentation.phase == .composer ? 18 : 16
    }

    private var surfaceAnimation: Animation? {
        if reduceMotion {
            return .easeInOut(duration: 0.10)
        }

        let duration = presentation.phase == .composer
            ? NotchComposerPanelLayout.resizeDuration
            : 0.22
        return .timingCurve(0.16, 1.0, 0.30, 1.0, duration: duration)
    }

    private var compactTransition: AnyTransition {
        .opacity
    }

    private var composerTransition: AnyTransition {
        .opacity
    }
}

struct NotchIdleView: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement()
            .accessibilityLabel("Garden Drop notch shortcut")
    }
}

struct NotchPeekView: View {
    let safeTopInset: CGFloat
    let captureState: NotchCaptureState
    let recentCapturePath: String?
    let onOpen: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: safeTopInset)

            HStack(spacing: 8) {
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        NotchCaptureStatusView(state: captureState)

                        Text(recentCapturePath ?? "Ready to plant")
                            .font(NotchTypography.font(11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.90))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open the Garden Drop capture surface")
                .accessibilityLabel(
                    "\(recentCapturePath ?? "Ready to plant"), \(captureState.accessibilityDescription)"
                )

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(NotchTypography.font(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: 20, height: 16)
                }
                .buttonStyle(.plain)
                .help("Open Garden Drop settings")
                .accessibilityLabel("Open Garden Drop settings")
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

}

private struct NotchCaptureStatusView: View {
    let state: NotchCaptureState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSavingAnimationActive = false

    var body: some View {
        ZStack {
            Circle()
                .fill(state == .done ? gardenLeaf : Color.white.opacity(0.10))
                .frame(width: 16, height: 16)

            stateMark
                .id(state)
                .transition(.opacity)
        }
        .frame(width: 16, height: 16)
        .animation(
            reduceMotion ? .easeOut(duration: 0.10) : .easeOut(duration: 0.22),
            value: state
        )
        .accessibilityHidden(true)
        .onAppear {
            synchronizeSavingAnimation(for: state)
        }
        .onChange(of: state) { _, newState in
            synchronizeSavingAnimation(for: newState)
        }
    }

    @ViewBuilder
    private var stateMark: some View {
        switch state {
        case .idle:
            Circle()
                .strokeBorder(Color.white.opacity(0.62), lineWidth: 1.4)
                .frame(width: 6, height: 6)
        case .saving:
            Circle()
                .trim(from: 0.10, to: 0.82)
                .stroke(
                    gardenRust.opacity(0.90),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(isSavingAnimationActive ? 360 : 0))
                .animation(
                    reduceMotion
                        ? nil
                        : .linear(duration: 0.90).repeatForever(autoreverses: false),
                    value: isSavingAnimationActive
                )
        case .done:
            Image(systemName: "checkmark")
                .font(NotchTypography.font(8, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func synchronizeSavingAnimation(for state: NotchCaptureState) {
        guard state == .saving, !reduceMotion else {
            isSavingAnimationActive = false
            return
        }

        isSavingAnimationActive = false
        DispatchQueue.main.async {
            isSavingAnimationActive = true
        }
    }

    private var gardenRust: Color {
        Color(red: 0.741, green: 0.329, blue: 0.220)
    }

    private var gardenLeaf: Color {
        Color(red: 0.325, green: 0.427, blue: 0.349)
    }
}

struct NotchSurfaceBackground: View {
    var body: some View {
        Color(red: 0.055, green: 0.059, blue: 0.063)
    }
}

struct NotchSurfaceShape: Shape {
    let bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(bottomCornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()

        return path
    }
}
