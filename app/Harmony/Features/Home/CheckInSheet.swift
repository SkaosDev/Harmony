import SwiftData
import SwiftUI

/// `V2-AccueilEnergie` (TODO 6.9): the optional row above the situations, and how many answers
/// this week. Active mode only; it never stands between Home and the music (NFR5).
struct EnergyRow: View {
    let answersThisWeek: Int
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CheckInTexts.rowTitle)
                            .font(Theme.font(size: 16, bold: true))
                            .designLineHeight(16 * 1.2)
                            .foregroundStyle(Theme.textPrimary)
                        Text(CheckInTexts.rowDetail)
                            .font(Theme.font(size: 13))
                            .designLineHeight(13 * 1.3)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    StrokeIcon(lines: [[(9, 5), (16, 12), (9, 19)]])
                        .stroke(Theme.textSecondary, style: StrokeIcon.style(2, size: 22))
                        .frame(width: 22, height: 22)
                }
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .frame(minHeight: 64)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            CardText(text: CheckInTexts.learning(answersThisWeek: answersThisWeek))
        }
    }
}

/// `V2-CheckIn` (TODO 6.9): energy on 7 steps (−3…+3) with the last answer marked, the optional
/// pleasantness question, Save or Not now. The model's estimate is never shown before the answer.
struct CheckInSheet: View {
    /// The previous energy answer, −3…+3.
    let last: Int?
    /// Save: energy, then pleasantness if given.
    let onSave: (Int, Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var energy: Int?
    @State private var pleasantness: Int?
    @State private var height: CGFloat = 560

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.neutralTile)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text(CheckInTexts.sheetTitle)
                    .font(Theme.font(size: 26, bold: true))
                    .tracking(-0.6)
                    .designLineHeight(26 * 1.15)
                    .foregroundStyle(Theme.textPrimary)
                CardText(text: CheckInTexts.sheetText)
            }
            Scale(label: CheckInTexts.sheetTitle, selection: $energy, low: CheckInTexts.low, high: CheckInTexts.high,
                  marked: last)
            CardDivider()
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(CheckInTexts.pleasantnessQuestion)
                        .font(Theme.font(size: 16, bold: true))
                        .designLineHeight(16 * 1.2)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                    CardLabel(text: CheckInTexts.optional)
                }
                Scale(label: CheckInTexts.pleasantnessQuestion, selection: $pleasantness,
                      low: CheckInTexts.unpleasant, high: CheckInTexts.pleasant, marked: nil)
            }
            VStack(spacing: 12) {
                PillButton(CheckInTexts.save) {
                    if let energy { onSave(energy, pleasantness) }
                    dismiss()
                }
                .disabled(energy == nil)
                .opacity(energy == nil ? 0.5 : 1)
                PillButton(CheckInTexts.notNow, style: .outline) { dismiss() }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(8)
        .presentationBackground(Theme.tile)
        .preferredColorScheme(.dark)
    }
}

/// Seven 44 pt circles, `#535353` (the design's `#2A2A2A` could not be seen on the sheet), the
/// chosen one green; the end labels below, and "Last" in white under the previous answer (it
/// takes the end label's place at either end).
private struct Scale: View {
    let label: String
    @Binding var selection: Int?
    let low: String
    let high: String
    let marked: Int?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(-3...3, id: \.self) { value in
                    Button { selection = value } label: {
                        Circle()
                            .fill(selection == value ? Theme.accent : Theme.neutralTile)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value + 4) of 7")
                    .accessibilityAddTraits(selection == value ? [.isSelected] : [])
                    if value < 3 { Spacer(minLength: 0) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            HStack(spacing: 8) {
                ForEach(-3...3, id: \.self) { value in
                    Text(text(value))
                        .font(Theme.font(size: 11, bold: true))
                        .designLineHeight(11 * 1.2)
                        .foregroundStyle(value == marked ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: value == -3 ? .leading : value == 3 ? .trailing : .center)
                }
            }
        }
    }

    private func text(_ value: Int) -> String {
        if value == marked { return CheckInTexts.last }
        return value == -3 ? low : value == 3 ? high : ""
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        CheckInSheet(last: 0) { _, _ in }
    }
}
