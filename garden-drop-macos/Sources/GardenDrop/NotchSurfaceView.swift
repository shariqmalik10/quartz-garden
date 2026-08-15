import SwiftUI

enum NotchSurfacePhase: Equatable {
    case idle
    case peek
    case composer
}

@MainActor
final class NotchSurfacePresentation: ObservableObject {
    @Published private(set) var phase: NotchSurfacePhase = .idle
    @Published private(set) var composerModel: CaptureComposerModel?
    @Published var safeTopInset: CGFloat = 0

    func showIdle() {
        phase = .idle
        composerModel = nil
    }

    func showPeek() {
        phase = .peek
        composerModel = nil
    }

    func showComposer(_ model: CaptureComposerModel) {
        composerModel = model
        phase = .composer
    }
}

struct NotchSurfaceRootView: View {
    @ObservedObject var presentation: NotchSurfacePresentation

    let onOpen: () -> Void
    let onSettings: () -> Void
    let onClose: () -> Void

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
                    onClose: onClose
                )
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
        reduceMotion
            ? .easeOut(duration: 0.10)
            : .timingCurve(0.16, 1.0, 0.30, 1.0, duration: 0.24)
    }

    private var compactTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
            removal: .opacity
        )
    }

    private var composerTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.975, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.99, anchor: .top))
        )
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
    let onOpen: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: safeTopInset)

            HStack(spacing: 8) {
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(gardenRust)
                            .frame(width: 6, height: 6)

                        Text("Garden Drop")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.90))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open the Garden Drop capture surface")
                .accessibilityLabel("Open Garden Drop capture surface")

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: 20, height: 16)
                }
                .buttonStyle(.plain)
                .help("Open Garden Drop settings")
                .accessibilityLabel("Open Garden Drop settings")
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var gardenRust: Color {
        Color(red: 0.82, green: 0.38, blue: 0.25)
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
