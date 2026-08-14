import SwiftUI

struct NotchIdleView: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text("Garden Drop")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
        .frame(width: 196, height: 32)
        .background(Color.black)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Garden Drop")
    }
}

struct NotchPeekView: View {
    let onOpen: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(gardenRust)
                .frame(width: 25, height: 25)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Ready to plant")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("example.com")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Open Garden Drop settings")
            .accessibilityLabel("Open Garden Drop settings")

            Button(action: onOpen) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.return)
            .help("Open capture composer")
            .accessibilityLabel("Open capture composer")
        }
        .padding(.horizontal, 8)
        .frame(width: 224, height: 48)
        .background(Color.black)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var gardenRust: Color {
        Color(red: 0.82, green: 0.38, blue: 0.25)
    }
}
