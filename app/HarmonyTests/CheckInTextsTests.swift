import Testing
@testable import Harmony

/// TODO 6.9, 6.13: no new text names an emotion or makes a medical claim (list of TODO 3.7). The
/// optional pleasantness question is the one exception, for "feel", "pleasant" and "unpleasant"
/// only (decision D2: internal, never shown back).
@MainActor
struct CheckInTextsTests {
    /// The words the pleasantness question needs, and nothing else from the list.
    static let pleasantnessAllowed = ["feel", "pleasant", "unpleasant"]

    private func forbiddenWords(in text: String, allowing allowed: [String] = []) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init).filter { word in
            !allowed.contains(word) && ExplainerTests.forbidden.contains { word.hasPrefix($0) }
        }
    }

    @Test func noTextUsesAForbiddenWord() {
        #expect(CheckInTexts.all.count > 40)
        for text in CheckInTexts.all {
            #expect(forbiddenWords(in: text).isEmpty, "\(text)")
        }
        for action in CheckInNotifications.Action.allCases {
            #expect(forbiddenWords(in: action.title).isEmpty)
        }
    }

    @Test func pleasantnessQuestionUsesOnlyItsExceptions() {
        for text in CheckInTexts.pleasantness {
            #expect(forbiddenWords(in: text, allowing: Self.pleasantnessAllowed).isEmpty, "\(text)")
        }
        // The exceptions are needed: without them the test would flag the question.
        #expect(!forbiddenWords(in: CheckInTexts.pleasantnessQuestion).isEmpty)
    }

    @Test func learningCounterSaysAnswerOrAnswers() {
        #expect(CheckInTexts.learning(answersThisWeek: 4) == "Harmony is learning your usual — 4 answers this week")
        #expect(CheckInTexts.learning(answersThisWeek: 1) == "Harmony is learning your usual — 1 answer this week")
    }
}
