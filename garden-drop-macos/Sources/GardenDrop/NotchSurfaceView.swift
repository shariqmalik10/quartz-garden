import SwiftUI

struct NotchIdleView: View {
    let size: CGSize

    var body: some View {
        Color.black
            .frame(width: size.width, height: size.height)
            .clipShape(NotchSurfaceShape(bottomCornerRadius: min(14, size.height / 2)))
            .accessibilityElement()
            .accessibilityLabel("Open Garden Drop")
    }
}

struct NotchPeekView: View {
    let size: CGSize
    let safeTopInset: CGFloat
    let onOpen: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: min(safeTopInset, size.height))

            HStack(spacing: 8) {
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(gardenRust)
                            .frame(width: 6, height: 6)

                        Text("Garden Drop")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
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
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(width: 20, height: 18)
                }
                .buttonStyle(.plain)
                .help("Open Garden Drop settings")
                .accessibilityLabel("Open Garden Drop settings")
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: max(16, size.height - safeTopInset))
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .clipShape(NotchSurfaceShape(bottomCornerRadius: min(16, size.height / 2)))
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
