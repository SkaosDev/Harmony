import SwiftUI

/// The design's small pill: 22 pt high, 10 pt side padding, 11 pt bold.
struct Badge: View {
    let text: String
    var background = Color(hex: 0x2A2A2A)
    var foreground = Theme.textPrimary

    init(_ text: String, background: Color = Color(hex: 0x2A2A2A), foreground: Color = Theme.textPrimary) {
        self.text = text
        self.background = background
        self.foreground = foreground
    }

    var body: some View {
        Text(text)
            .font(Theme.font(size: 11, bold: true))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(background, in: Capsule())
            .fixedSize()
    }
}
