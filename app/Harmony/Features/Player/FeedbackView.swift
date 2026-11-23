import SwiftUI

/// "Did it fit?" at the end of a queue (`docs/design/V2-Feedback.dc.html`, TODO 3.15, FR10):
/// Yes → `fitYes`, Nope → `fitNo`, Skip → nothing recorded.
struct FeedbackView: View {
    /// True for Yes, false for Nope, nil for Skip.
    let onAnswer: (Bool?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 14) {
                Text("End of the queue")
                    .font(Theme.font(size: 12, bold: true))
                    .designLineHeight(12 * 1.2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Did it fit?")
                    .font(Theme.font(size: 56, bold: true))
                    .tracking(-2.5)
                    .designLineHeight(56)
                    .foregroundStyle(Theme.textPrimary)
                Text("One tap helps us pick a better queue next time.")
                    .font(Theme.font(size: 16))
                    .designLineHeight(16 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    tile("Yes", icon: StrokeIcon(lines: [[(5, 13), (9, 17), (19, 7)]]), color: Theme.accent) { onAnswer(true) }
                    tile("Nope", icon: StrokeIcon(lines: [[(6, 6), (18, 18)], [(18, 6), (6, 18)]]), color: Theme.stress) { onAnswer(false) }
                }
                Button { onAnswer(nil) } label: {
                    Text("Skip")
                        .font(Theme.font(size: 16, bold: true))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                        .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private func tile(_ title: String, icon: StrokeIcon, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                icon
                    .stroke(color, style: StrokeStyle(lineWidth: 2.2 * 40 / 24, lineCap: .round, lineJoin: .round))
                    .frame(width: 40, height: 40)
                Text(title)
                    .font(Theme.font(size: 18, bold: true))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// An SVG icon made of polylines, given in the design's 24 × 24 box.
nonisolated struct StrokeIcon: Shape {
    let lines: [[(CGFloat, CGFloat)]]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        for line in lines {
            path.addLines(line.map { CGPoint(x: rect.minX + $0.0 * scale, y: rect.minY + $0.1 * scale) })
        }
        return path
    }
}

#Preview {
    FeedbackView { _ in }
}
