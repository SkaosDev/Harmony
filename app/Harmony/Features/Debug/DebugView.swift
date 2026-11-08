#if DEBUG
import SwiftUI

/// Developer screen, Debug builds only, opened from Settings.
/// Content: TODO 1.17 (demo mode switch) and 2.22 (current features and state).
struct DebugView: View {
    var body: some View {
        Color.clear
            .background(Theme.background)
            .navigationTitle("Debug")
    }
}
#endif
