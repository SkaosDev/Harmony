import SwiftUI

/// A row with a 48 pt coloured tile (radius 4), as in the onboarding: 12 pt gap, 4 pt vertical
/// padding, title 16 pt bold, optional detail 13 pt grey, optional number in the tile (17 pt) or
/// the song's cover in its place, and what comes at the right end (badges and buttons of
/// `V2-File`, 4 pt apart).
struct TileRow<Trailing: View>: View {
    let color: Color
    var number: String?
    /// Spotify's cover, unmodified (NFR6), instead of the design's coloured placeholder.
    var cover: URL?
    let title: String
    var detail: String?
    var titleColor = Theme.textPrimary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 48, height: 48)
                .overlay {
                    if let cover {
                        AsyncImage(url: cover) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                    } else if let number {
                        Text(number)
                            .font(Theme.font(size: 17, bold: true))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(size: 16, bold: true))
                    .designLineHeight(16 * 1.2)
                    .foregroundStyle(titleColor)
                if let detail {
                    Text(detail)
                        .font(Theme.font(size: 13))
                        .designLineHeight(13 * 1.3)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) { trailing }
        }
        .padding(.vertical, 4)
    }
}

extension TileRow where Trailing == EmptyView {
    init(color: Color, number: String? = nil, title: String, detail: String? = nil) {
        self.init(color: color, number: number, title: title, detail: detail) { EmptyView() }
    }
}

/// The onboarding's 6-step progress: 4 pt segments (radius 2), 4 pt apart, in a 32 pt row;
/// done steps white, the others `#535353`.
struct OnboardingProgress: View {
    /// 1…6.
    let step: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= step ? Theme.textPrimary : Theme.neutralTile)
                    .frame(height: 4)
            }
        }
        .frame(height: 32)
    }
}

/// The design's progress bar: 6 pt high, radius 3, `#4D4D4D` track, green fill.
struct ProgressTrack: View {
    /// 0…1.
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}
