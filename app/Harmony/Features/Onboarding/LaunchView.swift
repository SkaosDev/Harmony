import SwiftData
import SwiftUI

/// "Loading your library" (`docs/design/V2-Main.dc.html`, TODO 3.16): shown after the onboarding
/// while the first import is not finished (the user tapped "Go to home" early, or the app was
/// closed during the import). Home follows as soon as the songs are in.
struct LaunchView: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Environment(LibrarySync.self) private var library

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("Harmony")
                .font(Theme.font(size: 60, bold: true))
                .tracking(-3)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                ProgressTrack(fraction: library.fraction)
                Text("Loading your library")
                    .font(Theme.font(size: 12, bold: true))
                    .designLineHeight(12 * 1.2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .task {
            // Already running if it started during the onboarding: `run` then does nothing.
            guard let music = try? DemoMode.musicProvider(demoMode) else { return }
            await library.run(music: music, scorer: DemoMode.scorer(demoMode), context: context)
        }
    }
}

#Preview {
    LaunchView()
        .environment(LibrarySync())
}
