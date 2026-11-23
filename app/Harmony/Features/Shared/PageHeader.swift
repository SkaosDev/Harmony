import SwiftUI

/// Back: a 26 pt chevron in a 32 × 40 frame, 8 pt into the left margin.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            StrokeIcon(lines: [[(15, 5), (8, 12), (15, 19)]])
                .stroke(Theme.textPrimary, style: StrokeIcon.style(2.2, size: 26))
                .frame(width: 26, height: 26)
                .frame(width: 32, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .padding(.leading, -8)
    }
}

/// The player's page title: 26 pt, 800, −0.6 tracking, line height 1.15, taking the free width.
struct PageTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.font(size: 26, bold: true))
            .tracking(-0.6)
            .designLineHeight(26 * 1.15)
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
