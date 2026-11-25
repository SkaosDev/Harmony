import SwiftUI

/// Settings tab (TODO 3.19, 6.13, `docs/design/V2-Reglages.dc.html`): the five pages, the Demo mode
/// switch and, in Debug builds only, the Debug screen. The design centres the list in the free
/// space; it sits under the title, as Clément asked for Home (23 Nov.).
struct SettingsView: View {
    @AppStorage(DemoMode.key) private var demoMode = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle("Settings")
                VStack(spacing: 10) {
                    page(Theme.accent, "Spotify account") { SpotifyAccountView() }
                    page(Theme.stress, "Health data") { HealthDataView() }
                    page(Situation.windDown.color, CheckInTexts.questions) { QuestionsView() }
                    page(Theme.blue, "My data") { MyDataView() }
                    page(Theme.wakeUp, "About & privacy") { AboutView() }
                    TileRow(color: Situation.lowEnergy.color, title: "Demo mode", detail: "Recorded data, no watch needed.") {
                        DesignSwitch(isOn: $demoMode, label: "Demo mode")
                    }
                    #if DEBUG
                    // The Debug screen is not in the design.
                    page(Theme.neutralTile, "Debug") { DebugView() }
                    #endif
                }
            }
            .padding(EdgeInsets(top: 56, leading: 16, bottom: 0, trailing: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background)
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// A row of the design: coloured tile, title, chevron (22 pt, `#B3B3B3`).
    private func page(_ color: Color, _ title: String, @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink(destination: destination) {
            TileRow(color: color, title: title) {
                StrokeIcon(lines: [[(9, 5), (16, 12), (9, 19)]])
                    .stroke(Theme.textSecondary, style: StrokeIcon.style(2, size: 22))
                    .frame(width: 22, height: 22)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A Settings page: Back and the title, the content below, the bottom part at the bottom;
/// margins 56 / 16 / 24.
struct SettingsPage<Content: View, Bottom: View>: View {
    let title: String
    var spacing: CGFloat = 16
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: spacing) {
                HStack(spacing: 8) {
                    BackButton { dismiss() }
                    PageTitle(title)
                }
                content
            }
            Spacer(minLength: 20)
            bottom
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The design's switch: 48 × 28, `#727272` off, green on, white 22 pt knob 3 pt inside.
struct DesignSwitch: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button { isOn.toggle() } label: {
            Capsule()
                .fill(isOn ? Theme.accent : Theme.outline)
                .frame(width: 48, height: 28)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 22, height: 22).padding(3)
                }
                .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

extension View {
    /// The design's card: `#181818`, radius 8, 16 pt padding (`padding` to change it).
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Grey 12 pt bold label (line height 1.2) and grey 13 pt text (line height 1.4) of the cards.
struct CardLabel: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.font(size: 12, bold: true)).designLineHeight(12 * 1.2).foregroundStyle(Theme.textSecondary)
    }
}

struct CardText: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.font(size: 13)).designLineHeight(13 * 1.4).foregroundStyle(Theme.textSecondary)
    }
}

/// A 1 pt `#333333` line between the rows of a card.
struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
    }
}
