import SwiftUI

/// Settings tab. Content: TODO 3.19 (`docs/design/V2-Reglages.dc.html`).
/// In Debug builds only, it also leads to the Debug screen.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                #if DEBUG
                NavigationLink {
                    DebugView()
                } label: {
                    // Same row layout as the design's settings rows; the Debug screen itself is not in the design.
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.neutralTile)
                            .frame(width: 48, height: 48)
                        Text("Debug")
                            .font(Theme.font(size: 16, bold: true))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                #endif
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
