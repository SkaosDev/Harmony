import SwiftUI

/// The player (TODO 3.18): "Now playing" (`docs/design/V2-Lecture.dc.html`) and its "Up next"
/// list (`V2-File`), "Did it fit?" at the end of the queue (`V2-Feedback`), "Can't play this" when
/// Spotify refused (`V2-LectureImpossible`).
struct PlayerView: View {
    @Environment(PlayerController.self) private var player
    @State private var showsQueue = false

    var body: some View {
        Group {
            switch player.phase {
            case .ended:
                FeedbackView { player.answer(fits: $0) }
            case .cannotPlay:
                CannotPlayView()
            default:
                if showsQueue {
                    UpNextView { showsQueue = false }
                } else {
                    NowPlayingView { showsQueue = true }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// `V2-Lecture`: margins 56 / 16 / 24 on `#191414`; header, cover and song, then the controls.
struct NowPlayingView: View {
    let onShowQueue: () -> Void
    @Environment(PlayerController.self) private var player

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                BackButton { player.isPresented = false }
                PageTitle(player.queue?.situation.title ?? "")
                Button { player.isPresented = false } label: {
                    Text("Change")
                        .font(Theme.font(size: 13, bold: true))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 16) {
                cover
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song?.title ?? " ")
                            .font(Theme.font(size: 22, bold: true))
                            .tracking(-0.4)
                            .foregroundStyle(Theme.textPrimary)
                        Text(song?.artists.joined(separator: ", ") ?? " ")
                            .font(Theme.font(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SpotifyLogo()
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ProgressTrack(fraction: fraction(at: context.date))
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 14) {
                controls
                PillButton("Play on Spotify", style: .outline, spotifyIcon: true) { player.openInSpotify() }
                Button(action: onShowQueue) {
                    HStack(spacing: 12) {
                        Text("Up next")
                            .font(Theme.font(size: 14, bold: true))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Badge(counter)
                        StrokeIcon(lines: [[(9, 5), (16, 12), (9, 19)]])
                            .stroke(Theme.textSecondary, style: StrokeIcon.style(2, size: 20))
                            .frame(width: 20, height: 20)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                Text(player.queue?.reason ?? "")
                    .font(Theme.font(size: 13))
                    .designLineHeight(13 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.player)
        .ignoresSafeArea()
    }

    private var song: TrackInfo? { player.currentSong }

    /// "2 / 5": place of the playing song among the songs still in the queue.
    private var counter: String {
        let ids = player.activeIds
        let place = player.state?.spotifyId.flatMap(ids.firstIndex(of:)) ?? 0
        return "\(place + 1) / \(ids.count)"
    }

    /// Spotify's cover, unmodified and uncropped (NFR6), on the design's `#282828` box, 342 pt high.
    private var cover: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Theme.tile)
            .frame(height: 342)
            .overlay {
                AsyncImage(url: song?.coverURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Like (circle with a plus, 44 pt), Pause / Play (white 64 pt disc), Next (44 pt), spread
    /// over the width.
    private var controls: some View {
        HStack(spacing: 12) {
            let liked = player.state?.spotifyId.map(player.liked.contains) ?? false
            let likeColor = liked ? Theme.accent : Theme.textPrimary
            IconButton(liked ? "Added to Liked Songs" : "Add to Liked Songs") { Task { await player.like() } } icon: {
                ZStack {
                    Circle().inset(by: 3 * 26 / 24)
                        .stroke(likeColor, style: StrokeIcon.style(2.2, size: 26))
                    StrokeIcon(lines: [[(12, 8), (12, 16)], [(8, 12), (16, 12)]])
                        .stroke(likeColor, style: StrokeIcon.style(2.2, size: 26))
                }
            }
            Spacer(minLength: 0)
            Button { Task { await player.togglePause() } } label: {
                Group {
                    if player.state?.isPaused == true {
                        PlayTriangle().fill(.black)
                    } else {
                        StrokeIcon(lines: [[(8, 5), (8, 19)], [(16, 5), (16, 19)]])
                            .stroke(.black, style: StrokeIcon.style(2.2, size: 28))
                    }
                }
                .frame(width: 28, height: 28)
                .frame(width: 64, height: 64)
                .background(.white, in: Circle())
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.state?.isPaused == true ? "Play" : "Pause")
            Spacer(minLength: 0)
            IconButton("Next") { Task { await player.next() } } icon: {
                NextIcon().stroke(Theme.textPrimary, style: StrokeIcon.style(2.2, size: 26))
            }
        }
    }

    private func fraction(at date: Date) -> Double {
        guard let duration = player.state?.duration, duration > 0 else { return 0 }
        return player.position(at: date) / duration
    }
}

/// `V2-File`: the queue in order with the covers, the playing song in green with "Now", MuSe
/// suggestions marked "New", the last song "Goal"; the coming songs can be removed. The design
/// centres the list in the free space; Clément asked for it under the header (23 Nov.).
struct UpNextView: View {
    let onBack: () -> Void
    @Environment(PlayerController.self) private var player

    /// The tile colours of the design, in turn.
    private static let colors = [Theme.wakeUp, Theme.blue, Theme.stress, Theme.accent, Situation.lowEnergy.color]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    BackButton(action: onBack)
                    PageTitle("Up next")
                    SpotifyLogo()
                }
                if let queue = player.queue {
                    Text(Explainer.capitalized(Explainer.plan(situation: queue.situation, e0: queue.e0)))
                        .font(Theme.font(size: 13))
                        .designLineHeight(13 * 1.4)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }
            }
            .padding(.top, 20)
            Spacer(minLength: 16)
            PillButton("Back to player", style: .outline, action: onBack)
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .ignoresSafeArea()
    }

    private var rows: some View {
        VStack(spacing: 10) {
            if let queue = player.queue {
                let current = player.currentIndex ?? 0
                let shown = queue.entries.indices.filter { !player.removed.contains(queue.entries[$0].song.spotifyId) }
                ForEach(Array(shown.enumerated()), id: \.element) { place, index in
                    let entry = queue.entries[index]
                    let song = queue.songs[safe: index]
                    TileRow(color: Self.colors[place % Self.colors.count], number: "\(place + 1)",
                            cover: song?.coverURL,
                            title: song?.title ?? "",
                            detail: song?.artists.joined(separator: ", "),
                            titleColor: index == current ? Theme.accent : Theme.textPrimary) {
                        if index == current {
                            Badge("Now")
                        }
                        if entry.info != nil {
                            Badge("New", background: Theme.wakeUp, foreground: .black)
                        }
                        if index == queue.entries.count - 1 {
                            Badge("Goal", background: Theme.accent, foreground: .black)
                        }
                        if index > current {
                            IconButton("Remove this song") { player.remove(entry.song.spotifyId) } icon: {
                                StrokeIcon.cross.stroke(Theme.textPrimary, style: StrokeIcon.style(2.2, size: 26))
                            }
                        }
                    }
                    .lineLimit(1)
                }
            }
        }
    }
}

/// `V2-LectureImpossible`: the three usual causes, "Open Spotify" (plays the first song there,
/// TODO 3.13) and "Try again". The design has no Back: opening Spotify hands the queue over and
/// closes the player.
struct CannotPlayView: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                WarningIcon()
                    .stroke(Theme.textSecondary, style: StrokeIcon.style(2, size: 48))
                    .frame(width: 48, height: 48)
                Text("Can’t play this")
                    .font(Theme.font(size: 36, bold: true))
                    .tracking(-1.2)
                    .designLineHeight(36 * 1.08)
                    .foregroundStyle(Theme.textPrimary)
                Text("It’s usually one of these:")
                    .font(Theme.font(size: 16))
                    .designLineHeight(16 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
                VStack(spacing: 10) {
                    TileRow(color: Theme.wakeUp, number: "1", title: "Spotify isn’t installed")
                    TileRow(color: Theme.stress, number: "2", title: "The account isn’t Premium")
                    TileRow(color: Theme.blue, number: "3", title: "The connection dropped")
                }
            }
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                PillButton("Open Spotify", spotifyIcon: true) {
                    player.openInSpotify()
                    player.isPresented = false
                }
                PillButton("Try again", style: .outline) { Task { await player.retry() } }
            }
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea()
    }
}

/// Brings the player back once closed (not in the design: Clément's choice of 23 Nov.). It
/// takes the look of the "Up next" row of `V2-Lecture` (`#282828`, radius 8) with the cover
/// (40 pt, radius 4), the song (14 pt bold, artist 13 pt grey) and Pause / Play.
struct MiniPlayer: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.neutralTile)
                .frame(width: 40, height: 40)
                .overlay {
                    AsyncImage(url: player.currentSong?.coverURL) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentSong?.title ?? " ")
                    .font(Theme.font(size: 14, bold: true))
                    .foregroundStyle(Theme.textPrimary)
                Text(player.currentSong?.artists.joined(separator: ", ") ?? " ")
                    .font(Theme.font(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            let isPaused = player.state?.isPaused == true
            IconButton(isPaused ? "Play" : "Pause") { Task { await player.togglePause() } } icon: {
                if isPaused {
                    PlayTriangle().fill(Theme.textPrimary)
                } else {
                    StrokeIcon(lines: [[(8, 5), (8, 19)], [(16, 5), (16, 19)]])
                        .stroke(Theme.textPrimary, style: StrokeIcon.style(2.2, size: 26))
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { player.isPresented = true }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the player")
    }
}

// MARK: Parts

/// Spotify's full green logo in the design's 24 pt high slot (NFR6).
private struct SpotifyLogo: View {
    var body: some View {
        Image("SpotifyFullLogoGreen")
            .resizable()
            .scaledToFit()
            .frame(height: 24)
            .accessibilityLabel("Spotify")
    }
}

/// A 26 pt icon in a 44 pt round button.
private struct IconButton<Icon: View>: View {
    let label: String
    let action: () -> Void
    @ViewBuilder let icon: Icon

    init(_ label: String, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.label = label
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 26, height: 26)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// `M6 5l10 7-10 7zM19 5v14` in a 24 × 24 box.
private nonisolated struct NextIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        path.addLines([CGPoint(x: 6 * s, y: 5 * s), CGPoint(x: 16 * s, y: 12 * s), CGPoint(x: 6 * s, y: 19 * s)])
        path.closeSubpath()
        path.addLines([CGPoint(x: 19 * s, y: 5 * s), CGPoint(x: 19 * s, y: 19 * s)])
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// Play, while paused (the design only shows Pause): a triangle in the same 24 box.
private nonisolated struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        path.addLines([CGPoint(x: 7 * s, y: 5 * s), CGPoint(x: 19 * s, y: 12 * s), CGPoint(x: 7 * s, y: 19 * s)])
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// `M12 3l10 18H2z` and `M12 10v5M12 18v1` in a 24 × 24 box.
private nonisolated struct WarningIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        path.addLines([point(12, 3), point(22, 21), point(2, 21)])
        path.closeSubpath()
        path.addLines([point(12, 10), point(12, 15)])
        path.addLines([point(12, 18), point(12, 19)])
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
