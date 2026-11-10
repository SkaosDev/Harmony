import SwiftUI

/// Onboarding step 4 of 5, "Health data" (`docs/design/V2-Onb4-Sante.dc.html`): explains the four
/// signals before the system sheet (TODO 1.28). Opened from Debug until the onboarding exists (3.16).
struct HealthPermissionView: View {
    /// "Allow with Apple Health": asks for access, then goes on.
    let onAllow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progress
            VStack(alignment: .leading, spacing: 14) {
                Text("What your watch tells us")
                    .font(Theme.font(size: 36, bold: true))
                    .tracking(-1.2)
                    .designLineHeight(36 * 1.08)
                    .foregroundStyle(Theme.textPrimary)
                row(Theme.stress, "Heart rate", "Active more or less than usual?")
                row(Theme.accent, "Steps", "Moving or sitting still?")
                row(Theme.blue, "Sleep", "How was your last night?")
                row(Theme.wakeUp, "HRV", "Optional. Helps explain each queue.")
            }
            .padding(.top, 20)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 12) {
                Text("Read from Apple Health. Everything stays on your phone.")
                    .font(Theme.font(size: 13))
                    .designLineHeight(13 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
                Button(action: onAllow) {
                    HStack(spacing: 10) {
                        Text("Allow with Apple Health")
                            .font(Theme.font(size: 16, bold: true))
                        ArrowIcon()
                            .stroke(.black, style: StrokeStyle(lineWidth: 2.2 * 20 / 24, lineCap: .round, lineJoin: .round))
                            .frame(width: 20, height: 20)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                    .background(Theme.accent, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    /// Onboarding progress: step 4 of 5.
    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step < 4 ? Theme.textPrimary : Theme.neutralTile)
                    .frame(height: 4)
            }
        }
        .frame(height: 32)
    }

    private func row(_ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(size: 16, bold: true))
                    .designLineHeight(16 * 1.2)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.font(size: 13))
                    .designLineHeight(13 * 1.3)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The button's arrow: SVG path `M4 12h16M14 6l6 6-6 6` of the design, in a 24 × 24 box.
private nonisolated struct ArrowIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.move(to: point(4, 12))
        path.addLine(to: point(20, 12))
        path.move(to: point(14, 6))
        path.addLine(to: point(20, 12))
        path.addLine(to: point(14, 18))
        return path
    }
}

#Preview {
    HealthPermissionView {}
}
