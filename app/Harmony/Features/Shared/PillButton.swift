import SwiftUI

/// The design's full-width button: 52 pt high, pill-shaped, 16 pt bold, 10 pt between its
/// parts, 20 pt side padding, 1 pt border. Three styles: green (black text), outline (`#727272`
/// border) and destructive (`#E91429`).
struct PillButton: View {
    enum Style { case primary, outline, destructive }

    let title: String
    var style = Style.primary
    /// The official Spotify icon before the title (NFR6), in the design's 18 pt slot.
    var spotifyIcon = false
    /// The arrow after the title (`M4 12h16M14 6l6 6-6 6`, 20 pt).
    var arrow = false
    /// A 20 pt icon before the title (e.g. `StrokeIcon.download`), stroke 2.
    var icon: StrokeIcon?
    let action: () -> Void

    init(_ title: String, style: Style = .primary, spotifyIcon: Bool = false, arrow: Bool = false,
         icon: StrokeIcon? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.style = style
        self.spotifyIcon = spotifyIcon
        self.arrow = arrow
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if spotifyIcon {
                    // On green, Spotify's logo is black; on dark, white.
                    Image(style == .primary ? "SpotifyIconBlack" : "SpotifyIconWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                }
                if let icon {
                    icon.stroke(foreground, style: StrokeIcon.style(2, size: 20))
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(Theme.font(size: 16, bold: true))
                if arrow {
                    StrokeIcon.arrow
                        .stroke(foreground, style: StrokeIcon.style(2.2, size: 20))
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        style == .primary ? .black : Theme.textPrimary
    }

    private var background: Color {
        switch style {
        case .primary: Theme.accent
        case .outline: .clear
        case .destructive: Theme.destructive
        }
    }

    private var border: Color {
        switch style {
        case .primary: Theme.accent
        case .outline: Theme.outline
        case .destructive: Theme.destructive
        }
    }
}
