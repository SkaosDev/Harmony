import SwiftUI

/// Root screen: the selected tab above the design's tab bar.
struct RootView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .home: HomeView()
                case .library: LibraryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $selection)
        }
        // The tab bar reaches the bottom edge and keeps its own 26 pt bottom padding, as in the design.
        .ignoresSafeArea(edges: .bottom)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
