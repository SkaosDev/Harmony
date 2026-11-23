import SwiftData
import SwiftUI

/// Library tab (TODO 3.19b, `docs/design/V2-Bibliotheque.dc.html`): the imported songs with the
/// origin of their score, the share found in MuSe, a search and "Refresh the import". Songs with
/// a neutral score or no score yet have no pill (decided with Clément, 23 Nov.).
struct LibraryView: View {
    /// The design's placeholders for the covers, shown until Spotify's cover is loaded.
    private static let colors = [Theme.stress, Theme.accent, Theme.wakeUp, Theme.blue]

    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Environment(LibrarySync.self) private var library
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @Query private var scores: [SongScore]
    @State private var query = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PageTitle("My library")
                    SpotifyLogo()
                    Button { Task { await refresh() } } label: {
                        RefreshIcon()
                            .stroke(Theme.textPrimary, style: StrokeIcon.style(2.2, size: 26))
                            .frame(width: 26, height: 26)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh the import")
                    .disabled(library.isImporting)
                    .opacity(library.isImporting ? 0.4 : 1)
                }
                if let coverage = LibraryFigures.museCoverage(tracks: tracks, scores: scores) {
                    Text("\(Int((coverage * 100).rounded()))% found in MUSE.")
                        .font(Theme.font(size: 13))
                        .designLineHeight(13 * 1.4)
                        .foregroundStyle(Theme.textSecondary)
                }
                searchField
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    let origins = Dictionary(scores.map { ($0.spotifyId, $0.origin) }, uniquingKeysWith: { first, _ in first })
                    let shown = tracks.filter { LibraryFigures.matches(title: $0.title, artists: $0.artists, query: query) }
                    ForEach(Array(shown.enumerated()), id: \.element.spotifyId) { index, track in
                        TileRow(color: Self.colors[index % Self.colors.count], cover: track.coverURL,
                                title: track.title, detail: track.artists.joined(separator: ", ")) {
                            switch origins[track.spotifyId] {
                            case .muse: Badge("MUSE", background: Theme.blue, foreground: .black)
                            case .llm: Badge("Estimated", background: Situation.lowEnergy.color, foreground: Theme.textPrimary)
                            case .neutral, nil: EmptyView()
                            }
                        }
                        .lineLimit(1)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 0, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea(edges: .top)
        .alert("Something went wrong", isPresented: .constant(problem != nil)) {
            Button("OK") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    /// 48 pt, `#242424`, radius 4, 16 pt side padding, Helvetica Neue 500 at 16 pt. The design
    /// leaves the placeholder at the browser's default grey: the design's secondary grey here.
    private var searchField: some View {
        TextField("Search", text: $query, prompt: Text("Title or artist").foregroundStyle(Theme.textSecondary))
            .font(.custom("HelveticaNeue-Medium", size: 16))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(hex: 0x242424), in: RoundedRectangle(cornerRadius: 4))
    }

    /// Same as "Import again" in Settings (`SpotifyAccountView`).
    private func refresh() async {
        do {
            await library.run(music: try DemoMode.musicProvider(demoMode), scorer: DemoMode.scorer(demoMode), context: context)
            problem = library.problem
        } catch {
            problem = UserMessage.text(for: error)
        }
    }
}

/// The design's refresh icon, `M20 12a8 8 0 1 1-3-6.2M20 4v5h-5` in its 24 × 24 box: an arc
/// around (12, 12) from 3 o'clock, clockwise, to just past 1 o'clock, and the arrow head.
private nonisolated struct RefreshIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        // (20, 12) → (17, 5.8): atan2(−6.2, 5) = −51.1°, so 308.9° clockwise on screen.
        path.addRelativeArc(center: point(12, 12), radius: 8 * scale, startAngle: .degrees(0), delta: .degrees(308.9))
        path.addLines([point(20, 4), point(20, 9), point(15, 9)])
        return path
    }
}

#Preview {
    LibraryView()
        .environment(LibrarySync())
        .modelContainer(try! HarmonyStore.container(inMemory: true))
}
