import SwiftData
import SwiftUI

/// Home tab (TODO 3.17): the four situations, the suggested one marked "For you"
/// (`docs/design/V2-Accueil.dc.html`), or "Nothing to play yet" while no song has a score
/// (`V2-AccueilVide.dc.html`). One tap on a situation starts its queue (NFR5: ≤ 2 taps).
struct HomeView: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Environment(PlayerController.self) private var player
    @Environment(LibrarySync.self) private var library
    @Query private var scores: [SongScore]
    @State private var state: CurrentState?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if scores.isEmpty { empty } else { situations }
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 0, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea(edges: .top)
        .task { await computeState() }
        .alert("Can't start the queue", isPresented: .constant(problem != nil)) {
            Button("OK") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    // MARK: V2-Accueil

    /// The title, then the grid 20 pt below. The design centres the grid in the free space;
    /// Clément asked for it at the top (23 Nov.).
    private var situations: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text("What’s your moment?")
                    .font(Theme.font(size: 36, bold: true))
                    .tracking(-1.2)
                    .designLineHeight(36 * 1.08)
                    .foregroundStyle(Theme.textPrimary)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick a situation")
                    .font(Theme.font(size: 12, bold: true))
                    .designLineHeight(12 * 1.2)
                    .foregroundStyle(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Situation.allCases, id: \.self) { situation in
                        SituationTile(situation: situation, isSuggested: situation == suggestion) {
                            Task { await start(situation) }
                        }
                    }
                }
            }
        }
    }

    // MARK: V2-AccueilVide

    private var empty: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(spacing: 16) {
                    NoMusicIcon()
                        .stroke(Theme.textSecondary, style: StrokeIcon.style(2, size: 56))
                        .frame(width: 56, height: 56)
                    Text("Nothing to play yet")
                        .font(Theme.font(size: 26, bold: true))
                        .tracking(-0.6)
                        .designLineHeight(26 * 1.15)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your songs have no scores yet.")
                        .font(Theme.font(size: 16))
                        .designLineHeight(16 * 1.4)
                        .foregroundStyle(Theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                PillButton("Retry the import") { Task { await retryImport() } }
                PillButton("Use suggested tracks", style: .outline) { Task { await start(suggestion ?? timeOfDaySituation, museOnly: true) } }
            }
            .padding(.bottom, 12)
        }
    }

    /// "Harmony" and the watch badge: up to date when the estimate uses the watch (heart rate in
    /// the last 30 minutes), else "Watch not synced".
    private var header: some View {
        HStack(spacing: 12) {
            Text("Harmony")
                .font(Theme.font(size: 27, bold: true))
                .tracking(-1)
                .designLineHeight(27)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
            if state?.estimate.mode == .body {
                Badge("Watch up to date", background: Theme.accent, foreground: .black)
            } else {
                Badge("Watch not synced", background: Situation.lowEnergy.color)
            }
        }
    }

    // MARK: Logic

    /// The situation of `SituationSuggester` (TODO 3.8), once the state is known.
    private var suggestion: Situation? {
        guard let state else { return nil }
        return SituationSuggester.suggestion(at: state.date, hoursSinceWake: state.features["hours_since_wake"] ?? nil,
                                             e0: state.estimate.value)
    }

    /// "Use suggested tracks" with no suggestion: the situation of the time of day (Stress is
    /// never chosen for the user).
    private var timeOfDaySituation: Situation {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: .wakeUp
        case 12..<21: .lowEnergy
        default: .windDown
        }
    }

    private func computeState() async {
        do {
            state = try await CurrentState.compute(provider: DemoMode.healthProvider(demoMode), estimator: StateEstimator.bundled())
        } catch {
            print("State not computed: \(error)")
        }
    }

    private func start(_ situation: Situation, museOnly: Bool = false) async {
        do {
            if state == nil { await computeState() }
            guard let state else { throw CocoaError(.featureUnsupported) }
            let music = try DemoMode.musicProvider(demoMode)
            let maker = QueueMaker(context: context, catalog: try? MuseCatalog.bundled(), music: music)
            let queue = museOnly ? try await maker.prepareMuseOnly(situation, state: state)
                                 : try await maker.prepare(situation, state: state)
            guard !queue.entries.isEmpty else {
                problem = "No song fits this moment yet."
                return
            }
            await player.play(queue, playback: DemoMode.playback(demoMode), music: music, context: context)
        } catch {
            problem = "\(error)"
        }
    }

    private func retryImport() async {
        guard let music = try? DemoMode.musicProvider(demoMode) else { return }
        await library.run(music: music, scorer: DemoMode.scorer(demoMode), context: context)
    }
}

/// A situation tile of `V2-Accueil`: 150 pt high, radius 8, 12 pt padding, title 19 pt 800, the
/// "For you" badge at the bottom left, and the situation's shape in black at 35 %, 84 pt, turned
/// 25°, 14 pt past the right edge and 10 pt past the bottom.
private struct SituationTile: View {
    let situation: Situation
    let isSuggested: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                situation.shape
                    .fill(.black)
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(25))
                    .opacity(0.35)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 14, y: 10)
                Text(situation.title)
                    .font(Theme.font(size: 19, bold: true))
                    .tracking(-0.4)
                    .designLineHeight(19 * 1.1)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: 100, alignment: .leading)
                    .padding(12)
                if isSuggested {
                    Badge("For you")
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(situation.color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

extension Situation {
    /// The names of the design.
    var title: String {
        switch self {
        case .wakeUp: "Wake-up"
        case .stress: "Stress"
        case .lowEnergy: "Low energy"
        case .windDown: "Wind-down"
        }
    }

    /// Colours of the design.
    var color: Color {
        switch self {
        case .wakeUp: Theme.wakeUp
        case .stress: Theme.stress
        case .lowEnergy: Color(hex: 0xE13300)
        case .windDown: Color(hex: 0x477D95)
        }
    }

    /// Shapes of the tiles, in the design's 100 × 100 box.
    var shape: AnyShape {
        switch self {
        case .wakeUp: AnyShape(BoxPolygon(points: [(50, 8), (94, 88), (6, 88)]))
        case .stress: AnyShape(BoxPolygon(points: [(14, 14), (86, 14), (86, 86), (14, 86)]))
        case .lowEnergy: AnyShape(BoxPolygon(points: [(50, 4), (60, 32), (90, 30), (66, 48), (76, 76), (50, 60),
                                                      (24, 76), (34, 48), (10, 30), (40, 32)]))
        case .windDown: AnyShape(Circle().inset(by: 10))
        }
    }
}

/// A closed polygon in a 100 × 100 box.
private nonisolated struct BoxPolygon: Shape {
    let points: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.0 * scale, y: rect.minY + $0.1 * scale) })
        path.closeSubpath()
        return path
    }
}

/// `V2-AccueilVide`'s icon: a note crossed out (`M9 18V5l11-2v13`, circles at 6,18 and 17,16 of
/// radius 3, `M2 2l20 20`), in a 24 × 24 box.
private nonisolated struct NoMusicIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale) }
        var path = Path()
        path.addLines([point(9, 18), point(9, 5), point(20, 3), point(20, 16)])
        path.addEllipse(in: CGRect(x: rect.minX + 3 * scale, y: rect.minY + 15 * scale, width: 6 * scale, height: 6 * scale))
        path.addEllipse(in: CGRect(x: rect.minX + 14 * scale, y: rect.minY + 13 * scale, width: 6 * scale, height: 6 * scale))
        path.addLines([point(2, 2), point(22, 22)])
        return path
    }
}
