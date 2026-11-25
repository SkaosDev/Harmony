import SwiftData
import SwiftUI

/// First launch (TODO 3.16, PROJECT.md §2.4): the six onboarding screens of the design
/// (`V2-Onb1-Bienvenue` … `V2-Onb4b-Questions`, `V2-Onb5-Import`). Ends on Home; the import and the scores go on in the
/// background.
struct OnboardingView: View {
    /// "Go to home".
    let onFinish: () -> Void

    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Environment(LibrarySync.self) private var library
    @State private var step = 1
    @State private var problem: String?

    var body: some View {
        Group {
            switch step {
            case 1: welcome
            case 2: howItWorks
            case 3: spotify
            case 4: HealthPermissionView { Task { await allowHealth() } }
            case 5: questions
            default: importing
            }
        }
        .alert("Something went wrong", isPresented: .constant(problem != nil)) {
            Button("OK") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    // MARK: Screens

    /// `V2-Onb1-Bienvenue`
    private var welcome: some View {
        page(step: 1) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Harmony")
                    .font(Theme.font(size: 27, bold: true))
                    .tracking(-1)
                    .designLineHeight(27)
                title("Your music. Your body. The right moment.")
            }
        } bottom: {
            PillButton("Start", arrow: true) { step = 2 }
        }
    }

    /// `V2-Onb2-Comment`
    private var howItWorks: some View {
        page(step: 2) {
            VStack(alignment: .leading, spacing: 16) {
                title("How it works")
                TileRow(color: Theme.accent, number: "1", title: "Your music", detail: "Your Spotify songs, nothing else.")
                TileRow(color: Theme.blue, number: "2", title: "Your watch", detail: "Heart, steps, sleep. Stays on your phone.")
                TileRow(color: Theme.stress, number: "3", title: "The right queue", detail: "At the right time, in one tap.")
            }
        } bottom: {
            PillButton("Next", arrow: true) { step = 3 }
        }
    }

    /// `V2-Onb3-Spotify`
    private var spotify: some View {
        page(step: 3) {
            VStack(alignment: .leading, spacing: 16) {
                title("Plug in Spotify")
                Text("We pick from songs you already know. No made-up playlists.")
                    .font(Theme.font(size: 16))
                    .designLineHeight(16 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: 8) {
                    label("Songs we import")
                    TileRow(color: Theme.accent, title: "Liked songs")
                    TileRow(color: Theme.blue, title: "Top tracks")
                    TileRow(color: Theme.stress, title: "Recent plays")
                }
            }
        } bottom: {
            VStack(spacing: 12) {
                note("You sign in on Spotify’s secure page.")
                PillButton("Log in with Spotify", spotifyIcon: true, arrow: true) { Task { await signIn() } }
            }
        }
    }

    /// `V2-Onb4b-Questions` (TODO 6.13): the two daily questions, before the notification sheet.
    private var questions: some View {
        page(step: 5) {
            VStack(alignment: .leading, spacing: 14) {
                title(CheckInTexts.onboardingTitle)
                Text(CheckInTexts.onboardingText)
                    .font(Theme.font(size: 16))
                    .designLineHeight(16 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
                let tiles = CheckInTexts.onboardingTiles
                TileRow(color: Theme.accent, title: tiles[0].0, detail: tiles[0].1)
                TileRow(color: Theme.blue, title: tiles[1].0, detail: tiles[1].1)
                TileRow(color: Theme.wakeUp, title: tiles[2].0, detail: tiles[2].1)
                TileRow(color: Theme.stress, title: tiles[3].0, detail: tiles[3].1)
            }
        } bottom: {
            VStack(spacing: 12) {
                note(CheckInTexts.onboardingNote)
                PillButton(CheckInTexts.allowNotifications, arrow: true) { Task { await allowQuestions() } }
                PillButton(CheckInTexts.notNow, style: .outline) {
                    UserDefaults.standard.set(false, forKey: QuestionSettings.enabledKey)
                    step = 6
                }
            }
        }
    }

    /// `V2-Onb5-Import`
    private var importing: some View {
        page(step: 6) {
            VStack(alignment: .leading, spacing: 16) {
                title("Importing your library")
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        label("Songs")
                        Spacer(minLength: 0)
                        Text(library.fraction, format: .percent.precision(.fractionLength(0)))
                            .font(Theme.font(size: 27, bold: true))
                            .tracking(-0.2)
                            .designLineHeight(27 * 1.2)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    ProgressTrack(fraction: library.fraction)
                    Text("\(library.done.formatted()) of \(library.total.formatted()) songs. Scores are calculated once they are in.")
                        .font(Theme.font(size: 13))
                        .designLineHeight(13 * 1.4)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            }
        } bottom: {
            VStack(spacing: 12) {
                note("Your personal average is ready after 7 days.")
                PillButton("Go to home", arrow: true, action: onFinish)
            }
        }
        .task { await importLibrary() }
    }

    // MARK: Layout

    /// The onboarding layout: progress, then the content 20 pt below, the bottom part at the
    /// bottom; margins 56 / 16 / 24.
    private func page(step: Int, @ViewBuilder content: () -> some View, @ViewBuilder bottom: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgress(step: step)
            content()
                .padding(.top, 20)
            Spacer(minLength: 20)
            bottom()
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    /// The `h1` of the onboarding: 36 pt, 800, −1.2 tracking, line height 1.08.
    private func title(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(size: 36, bold: true))
            .tracking(-1.2)
            .designLineHeight(36 * 1.08)
            .foregroundStyle(Theme.textPrimary)
    }

    /// Small grey label: 12 pt, 700, line height 1.2.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(size: 12, bold: true))
            .designLineHeight(12 * 1.2)
            .foregroundStyle(Theme.textSecondary)
    }

    /// Centred grey note above a button: 13 pt, line height 1.4.
    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(size: 13))
            .designLineHeight(13 * 1.4)
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func signIn() async {
        do {
            try await DemoMode.musicProvider(demoMode).signIn()
            step = 4
        } catch {
            problem = "Spotify sign-in did not work. \(UserMessage.text(for: error))"
        }
    }

    /// HealthKit never says whether reading was refused: the choice made here is recorded in
    /// `Consent`, and the onboarding goes on either way (the app then runs on time of day only).
    private func allowHealth() async {
        do {
            try await DemoMode.healthProvider(demoMode).requestConsent(Set(HealthSignal.allCases))
            for signal in HealthSignal.allCases {
                context.insert(Consent(source: signal, granted: true, time: .now))
            }
            try context.save()
        } catch {
            print("Health access failed: \(error)")
        }
        step = 5
    }

    /// The questions are on only when iOS allows the notifications; the onboarding goes on
    /// either way.
    private func allowQuestions() async {
        let allowed = await CheckInNotifications.shared.requestAuthorization()
        UserDefaults.standard.set(allowed, forKey: QuestionSettings.enabledKey)
        if allowed {
            await CheckInNotifications.shared.reschedule(context: context)
        }
        step = 6
    }

    private func importLibrary() async {
        do {
            await library.run(music: try DemoMode.musicProvider(demoMode), scorer: DemoMode.scorer(demoMode), context: context)
            if let failure = library.problem {
                problem = "The import did not finish. \(failure)"
            }
        } catch {
            problem = UserMessage.text(for: error)
        }
    }
}

#Preview {
    OnboardingView {}
        .environment(LibrarySync())
}
