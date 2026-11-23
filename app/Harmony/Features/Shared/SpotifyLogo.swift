import SwiftUI

/// Spotify's full green logo in the design's 24 pt high slot (NFR6).
struct SpotifyLogo: View {
    var body: some View {
        Image("SpotifyFullLogoGreen")
            .resizable()
            .scaledToFit()
            .frame(height: 24)
            .accessibilityLabel("Spotify")
    }
}
