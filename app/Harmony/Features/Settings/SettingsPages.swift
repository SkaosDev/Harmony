import SwiftData
import SwiftUI
import UIKit

/// `V2-CompteSpotify` (TODO 1.26, 3.19): the account, the last import, "Import again" and
/// "Disconnect" (optionally deleting the library); after it, the onboarding starts again.
struct SpotifyAccountView: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @AppStorage(RootView.onboardedKey) private var onboarded = true
    @Environment(\.modelContext) private var context
    @Environment(LibrarySync.self) private var library
    @State private var profile: Profile?
    @State private var deleteLibrary = false
    @State private var problem: String?

    var body: some View {
        SettingsPage(title: "Spotify account", spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Theme.tile)
                        .frame(width: 52, height: 52)
                        .overlay {
                            AsyncImage(url: profile?.images?.first?.url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                        }
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        CardLabel(text: "Connected")
                        Text(profile?.display_name ?? " ")
                            .font(Theme.font(size: 16, bold: true))
                            .tracking(-0.2)
                            .designLineHeight(16 * 1.2)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                CardDivider()
                HStack(spacing: 12) {
                    Text("Last import")
                        .font(Theme.font(size: 16))
                        .designLineHeight(16 * 1.4)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                    Text(lastImport)
                        .font(Theme.font(size: 14, bold: true))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .card()
            PillButton("Import again") { Task { await importAgain() } }
                .disabled(library.isImporting)
        } bottom: {
            VStack(alignment: .leading, spacing: 16) {
                Button { deleteLibrary.toggle() } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(deleteLibrary ? Theme.accent : .clear)
                            .strokeBorder(deleteLibrary ? Theme.accent : Theme.outline, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if deleteLibrary {
                                    StrokeIcon.check.stroke(.black, style: StrokeIcon.style(2.4, size: 16)).frame(width: 16, height: 16)
                                }
                            }
                        Text("Also delete the imported library")
                            .font(Theme.font(size: 15))
                            .designLineHeight(15 * 1.3)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(deleteLibrary ? [.isToggle, .isSelected] : .isToggle)
                PillButton("Disconnect", style: .destructive) { disconnect() }
            }
            .card()
        }
        .task { profile = try? await SpotifyProvider.live.api.get("me") }
        .alert("Something went wrong", isPresented: .constant(problem != nil)) {
            Button("OK") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    private var lastImport: String {
        if library.isImporting { return library.fraction.formatted(.percent.precision(.fractionLength(0))) }
        return library.importedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
    }

    private func importAgain() async {
        do {
            await library.run(music: try DemoMode.musicProvider(demoMode), scorer: DemoMode.scorer(demoMode), context: context)
            problem = library.problem
        } catch {
            problem = UserMessage.text(for: error)
        }
    }

    private func disconnect() {
        do {
            try SpotifyProvider.live.signOut(deletingLibraryFrom: deleteLibrary ? context : nil)
            library.forget()
            onboarded = false
        } catch {
            problem = UserMessage.text(for: error)
        }
    }

    /// `GET /me`: the name and picture shown.
    private struct Profile: Decodable {
        struct Image: Decodable { let url: URL }
        let display_name: String?
        let images: [Image]?
    }
}

/// `V2-Sante` (TODO 3.19): each signal, its days of data and whether the user allowed it.
/// HealthKit never says whether reading was refused: the status is the one recorded at the
/// onboarding (`Consent`).
struct HealthDataView: View {
    @Query private var hours: [HourSummary]
    @Query private var nights: [NightSummary]
    @Query(sort: \Consent.time) private var consents: [Consent]
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsPage(title: "Health data & consents", spacing: 10) {
            row(.heartRate, Theme.stress, "Heart rate")
            row(.steps, Theme.accent, "Steps")
            row(.sleep, Theme.blue, "Sleep")
            row(.hrv, Theme.wakeUp, "HRV")
        } bottom: {
            VStack(alignment: .leading, spacing: 12) {
                CardText(text: "To remove access, go to iOS Settings → Health.")
                PillButton("Open iOS settings", style: .outline) {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
        }
    }

    private func row(_ signal: HealthSignal, _ color: Color, _ title: String) -> some View {
        TileRow(color: color, title: title, detail: signal == .hrv ? "Optional, works without it." : days(signal)) {
            if consents.last(where: { $0.source == signal })?.granted == true {
                Badge("Allowed", background: Theme.accent, foreground: .black)
            } else {
                Badge("Off")
            }
        }
    }

    /// "9 days of data": days with at least one known value (unknown is not zero).
    private func days(_ signal: HealthSignal) -> String {
        let calendar = Calendar.current
        let count: Int
        switch signal {
        case .heartRate: count = Set(hours.filter { $0.hrCount > 0 }.map { calendar.startOfDay(for: $0.hourStart) }).count
        case .steps: count = Set(hours.filter { $0.steps != nil }.map { calendar.startOfDay(for: $0.hourStart) }).count
        case .sleep: count = nights.filter { $0.sleepMinutes != nil }.count
        case .hrv: count = Set(hours.filter { $0.sdnnHRV != nil }.map { calendar.startOfDay(for: $0.hourStart) }).count
        }
        return count == 1 ? "1 day of data" : "\(count) days of data"
    }
}

/// `V2-MesDonnees` (TODO 3.19, FR13): what is stored, "Export as JSON", "Delete everything"
/// after a confirmation; the app then starts again at the onboarding.
struct MyDataView: View {
    @Environment(\.modelContext) private var context
    @Environment(LibrarySync.self) private var library
    @State private var counts = DataControl.Counts()
    @State private var export: ExportFile?
    @State private var confirmingDelete = false
    @State private var problem: String?

    var body: some View {
        SettingsPage(title: "My data") {
            CardText(text: "Everything stored on your phone, and nothing else.")
            VStack(spacing: 12) {
                count("Songs", counts.songs)
                CardDivider()
                count("Scores", counts.scores)
                CardDivider()
                count("Health summaries", counts.healthSummaries)
                CardDivider()
                count("Queues", counts.queues)
                CardDivider()
                count("Feedback", counts.feedback)
            }
            .card()
        } bottom: {
            VStack(spacing: 12) {
                PillButton("Export as JSON", icon: .download) { exportJSON() }
                PillButton("Delete everything", style: .destructive) { confirmingDelete = true }
            }
        }
        .task { refresh() }
        .sheet(item: $export) { ShareSheet(url: $0.url) }
        .confirmationDialog("Delete everything?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteAll() }
        } message: {
            Text("Songs, scores, health summaries, queues and feedback are deleted from this phone, and Spotify is disconnected. This cannot be undone.")
        }
        .alert("Something went wrong", isPresented: .constant(problem != nil)) {
            Button("OK") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    private func count(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.font(size: 16))
                .designLineHeight(16 * 1.4)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Text(value.formatted())
                .font(Theme.font(size: 20, bold: true))
                .tracking(-0.5)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func refresh() {
        counts = (try? DataControl.counts(in: context)) ?? DataControl.Counts()
    }

    private func exportJSON() {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("harmony-data.json")
            try DataControl.exportJSON(from: context).write(to: url, options: [.atomic, .completeFileProtection])
            export = ExportFile(url: url)
        } catch {
            problem = UserMessage.text(for: error)
        }
    }

    private func deleteAll() {
        do {
            try DataControl.deleteAll(in: context) { try SpotifyAuth.shared.signOut() }
            library.forget()
            refresh()
        } catch {
            problem = UserMessage.text(for: error)
        }
    }

    struct ExportFile: Identifiable {
        let url: URL
        var id: URL { url }
    }
}

/// The iOS share sheet for an exported file (also the pilot export of the Debug screen).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// `V2-APropos` (TODO 3.19): what Harmony does and does not do, where the data go, credits.
struct AboutView: View {
    var body: some View {
        SettingsPage(title: "About & privacy", spacing: 12) {
            Text("A wellbeing companion. Not a medical tool.")
                .font(Theme.font(size: 16, bold: true))
                .designLineHeight(16 * 1.35)
                .foregroundStyle(Theme.textPrimary)
                .card()
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    CardLabel(text: "It does")
                    CardText(text: "Picks songs from your own library for your moment.")
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .card(padding: 14)
                VStack(alignment: .leading, spacing: 6) {
                    CardLabel(text: "It doesn’t")
                    CardText(text: "Diagnose anything or promise any health effect.")
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .card(padding: 14)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                CardLabel(text: "Your data")
                CardText(text: "Health: stays on your phone.")
                CardText(text: "Titles and artists: sent to the scoring service, nothing else.")
            }
            .card()
        } bottom: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Badge("MUSE")
                    Badge("EmoPhone")
                    Badge("Spotify")
                }
                CardText(text: "Team G02 “FireStarter” · Hanyang University")
            }
        }
    }
}
