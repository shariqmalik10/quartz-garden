import SwiftUI

struct NotchPeekView: View {
    let onOpen: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(gardenRust)
                .frame(width: 42, height: 42)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("A small link, ready to plant")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("example.com · Link ready")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .help("Open Garden Drop settings")
            .accessibilityLabel("Open Garden Drop settings")

            Button(action: onOpen) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.return)
            .help("Open capture composer")
            .accessibilityLabel("Open capture composer")
        }
        .padding(.horizontal, 12)
        .frame(width: 340, height: 76)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var gardenRust: Color {
        Color(red: 0.741, green: 0.329, blue: 0.220)
    }
}
