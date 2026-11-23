import SwiftUI

/// An SVG icon of the design made of straight lines, given in its 24 × 24 box. Drawn with the
/// design's `stroke-width` scaled to the frame (`strokeWidth(for:)`).
nonisolated struct StrokeIcon: Shape {
    let lines: [[(CGFloat, CGFloat)]]

    /// `M4 12h16M14 6l6 6-6 6`: the arrow of the buttons.
    static let arrow = StrokeIcon(lines: [[(4, 12), (20, 12)], [(14, 6), (20, 12), (14, 18)]])
    /// `M5 13l4 4L19 7`
    static let check = StrokeIcon(lines: [[(5, 13), (9, 17), (19, 7)]])
    /// `M6 6l12 12M18 6L6 18`
    static let cross = StrokeIcon(lines: [[(6, 6), (18, 18)], [(18, 6), (6, 18)]])

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        for line in lines {
            path.addLines(line.map { CGPoint(x: rect.minX + $0.0 * scale, y: rect.minY + $0.1 * scale) })
        }
        return path
    }

    /// The design's `stroke-width` (in the 24 box) for an icon drawn `size` points wide.
    static func style(_ width: CGFloat, size: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width * size / 24, lineCap: .round, lineJoin: .round)
    }
}
