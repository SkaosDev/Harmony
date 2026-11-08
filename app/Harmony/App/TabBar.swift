import SwiftUI

/// The three tabs of the design, in order.
enum AppTab: CaseIterable {
    case home, library, settings

    var title: String {
        switch self {
        case .home: "Home"
        case .library: "Library"
        case .settings: "Settings"
        }
    }
}

/// Bottom navigation bar of `docs/design/V2-Accueil.dc.html` (`<nav>`).
struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                item(tab)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .padding(.bottom, 26)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.6), location: 0),
                    .init(color: .black, location: 0.4),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        let color = isSelected ? Theme.textPrimary : Theme.textSecondary
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                TabIcon(tab: tab)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 24, height: 24)
                Text(tab.title)
                    .font(Theme.font(size: 11, bold: isSelected))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Tab icons: the SVG paths of the design, drawn in a 24 × 24 box.
nonisolated struct TabIcon: Shape {
    let tab: AppTab

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        func line(_ path: inout Path, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            path.move(to: point(x1, y1))
            path.addLine(to: point(x2, y2))
        }

        var path = Path()
        switch tab {
        case .home:  // M3 11l9-8 9 8v10H3z
            path.move(to: point(3, 11))
            path.addLine(to: point(12, 3))
            path.addLine(to: point(21, 11))
            path.addLine(to: point(21, 21))
            path.addLine(to: point(3, 21))
            path.closeSubpath()
        case .library:  // M4 4v16M9 4v16M14 6l6 14
            line(&path, 4, 4, 4, 20)
            line(&path, 9, 4, 9, 20)
            line(&path, 14, 6, 20, 20)
        case .settings:  // circle r=3 + M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2
            path.addEllipse(in: CGRect(origin: point(9, 9), size: CGSize(width: 6 * scale, height: 6 * scale)))
            line(&path, 12, 2, 12, 5)
            line(&path, 12, 19, 12, 22)
            line(&path, 2, 12, 5, 12)
            line(&path, 19, 12, 22, 12)
            line(&path, 5, 5, 7, 7)
            line(&path, 17, 17, 19, 19)
            line(&path, 19, 5, 17, 7)
            line(&path, 7, 17, 5, 19)
        }
        return path
    }
}
