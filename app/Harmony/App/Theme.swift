import SwiftUI

/// Design tokens taken from `docs/design/` (only the ones used so far).
enum Theme {
    static let background = Color(hex: 0x121212)
    static let textPrimary = Color(hex: 0xFFFFFF)
    static let textSecondary = Color(hex: 0xB3B3B3)
    static let neutralTile = Color(hex: 0x535353)
    static let accent = Color(hex: 0x1ED760)
    static let blue = Color(hex: 0x509BF5)
    static let stress = Color(hex: 0xE8115B)
    static let wakeUp = Color(hex: 0xE8A21A)

    /// Helvetica Neue, as in the design. Weights 700 and 800 both map to Bold
    /// (the heaviest weight of Helvetica Neue on iOS).
    static func font(size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "HelveticaNeue-Bold" : "HelveticaNeue", size: size)
    }
}

extension View {
    /// The design's CSS `line-height`, in points (font size × factor). iOS 26 and later only;
    /// earlier systems keep the font's own line height.
    @ViewBuilder func designLineHeight(_ points: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            lineHeight(.exact(points: points))
        } else {
            self
        }
    }
}

extension Color {
    /// `Color(hex: 0x1ED760)` for the `#1ED760` of the design files.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
