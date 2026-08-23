import SwiftUI

enum DiaryDesign {
    static let canvas = Color(red: 17 / 255, green: 24 / 255, blue: 32 / 255)
    static let field = Color(red: 24 / 255, green: 35 / 255, blue: 44 / 255)
    static let text = Color(red: 244 / 255, green: 240 / 255, blue: 232 / 255)
    static let secondaryText = Color(red: 168 / 255, green: 181 / 255, blue: 182 / 255)
    static let signal = Color(red: 120 / 255, green: 199 / 255, blue: 176 / 255)
    static let record = Color(red: 240 / 255, green: 120 / 255, blue: 94 / 255)
    static let hairline = Color.white.opacity(0.12)
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(DiaryDesign.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
