import SwiftUI

/// The "Your answers" card of About (`V2-APropos`, TODO 6.16): what Harmony learned from the
/// answers of the last 14 days, then the two texts on local learning.
struct AnswersCard: View {
    let content: LearnedCurve.Content
    let now: Date

    init(answers: [CheckIn], now: Date = .now) {
        self.now = now
        content = LearnedCurve.content(answers: answers, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardLabel(text: CheckInTexts.answersLabel)
            learned
            CardText(text: CheckInTexts.answersTune)
            CardText(text: CheckInTexts.answersFade)
        }
        .card()
    }

    @ViewBuilder private var learned: some View {
        switch content {
        case .few(let count):
            VStack(alignment: .leading, spacing: 8) {
                Headline(text: CheckInTexts.learnedFew)
                CardText(text: CheckInTexts.curveAppears(soFar: count))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: LearnedChart.height)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Theme.divider, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }
        case .curve(let points, let headline):
            VStack(alignment: .leading, spacing: 8) {
                Headline(text: sentence(headline))
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1).fill(Theme.outline).frame(width: 16, height: 2)
                        SmallText(text: CheckInTexts.watchOnly, bold: true)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 16, height: 3)
                        SmallText(text: CheckInTexts.withYourAnswers, bold: true)
                    }
                }
                VStack(spacing: 4) {
                    LearnedChart(points: points, now: now)
                    AnswerMarks(points: points, now: now)
                    HStack(spacing: 8) {
                        SmallText(text: CheckInTexts.twoWeeksAgo)
                        Spacer(minLength: 0)
                        SmallText(text: CheckInTexts.today)
                    }
                }
            }
        }
    }

    private func sentence(_ headline: LearnedCurve.Headline) -> String {
        switch headline {
        case .more: CheckInTexts.learnedMore
        case .less: CheckInTexts.learnedLess
        case .noClearDifference: CheckInTexts.learnedSame
        }
    }
}

/// The two estimates over the 14 days: the watch alone in grey, with the answers in green, the
/// usual as a dashed line at 0.5. 80 pt high, 4 pt inset on each side.
private struct LearnedChart: View {
    static let height: CGFloat = 80
    let points: [LearnedCurve.Point]
    let now: Date

    var body: some View {
        Canvas { context, size in
            func position(_ point: LearnedCurve.Point, _ value: Double) -> CGPoint {
                CGPoint(x: Self.x(point.answeredAt, now: now, width: size.width), y: (1 - value) * size.height)
            }
            func line(_ value: KeyPath<LearnedCurve.Point, Double>) -> Path {
                Path { $0.addLines(points.map { position($0, $0[keyPath: value]) }) }
            }
            let usual = Path {
                $0.move(to: CGPoint(x: 0, y: size.height / 2))
                $0.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
            context.stroke(usual, with: .color(Theme.track), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            context.stroke(line(\.watchOnly), with: .color(Theme.outline),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            context.stroke(line(\.withAnswers), with: .color(Theme.accent),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                let center = position(last, last.withAnswers)
                let dot = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(Theme.accent))
                context.stroke(dot, with: .color(Theme.card), lineWidth: 2)
            }
        }
        .accessibilityHidden(true)
        .frame(height: Self.height)
        .overlay(alignment: .topLeading) { SmallText(text: CheckInTexts.moreEnergy) }
        .overlay(alignment: .bottomLeading) { SmallText(text: CheckInTexts.lessEnergy) }
        .overlay(alignment: .topTrailing) { SmallText(text: CheckInTexts.yourUsual).padding(.top, Self.height / 2 + 3) }
    }

    /// Horizontal position of an answer: 14 days ago at the left, now at the right.
    nonisolated static func x(_ date: Date, now: Date, width: CGFloat) -> CGFloat {
        4 + (1 - now.timeIntervalSince(date) / PersonalLayer.window) * (width - 8)
    }
}

/// One mark per answer under the curve: up, above the usual; down, below; ring, not compared yet.
private struct AnswerMarks: View {
    let points: [LearnedCurve.Point]
    let now: Date

    var body: some View {
        Canvas { context, size in
            for point in points {
                let x = LearnedChart.x(point.answeredAt, now: now, width: size.width)
                switch point.above {
                case true?:
                    context.fill(Path { $0.addLines([CGPoint(x: x - 3, y: 8.5), CGPoint(x: x, y: 2), CGPoint(x: x + 3, y: 8.5)]) },
                                 with: .color(Theme.textPrimary))
                case false?:
                    context.fill(Path { $0.addLines([CGPoint(x: x - 3, y: 1.5), CGPoint(x: x + 3, y: 1.5), CGPoint(x: x, y: 8)]) },
                                 with: .color(Theme.outline))
                case nil:
                    context.stroke(Path(ellipseIn: CGRect(x: x - 2.5, y: 2.5, width: 5, height: 5)),
                                   with: .color(Theme.outline), lineWidth: 1.2)
                }
            }
        }
        .accessibilityHidden(true)
        .frame(height: 10)
    }
}

/// White 13 pt bold sentence (line height 1.4).
private struct Headline: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.font(size: 13, bold: true)).designLineHeight(13 * 1.4).foregroundStyle(Theme.textPrimary)
    }
}

/// Grey 11 pt label of the chart (line height 1.2).
private struct SmallText: View {
    let text: String
    var bold = false
    var body: some View {
        Text(text).font(Theme.font(size: 11, bold: bold)).designLineHeight(11 * 1.2).foregroundStyle(Theme.textSecondary)
    }
}
