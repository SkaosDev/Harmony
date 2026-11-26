import Foundation

/// Every text of the "Harmony learns your usual" screens (TODO 6.9, 6.10, 6.13; design v2 §5.1,
/// copied from `docs/design/V2-*.dc.html`), in one place for the customer's reading and the
/// forbidden-word test (`CheckInTextsTests`, list of TODO 3.7). Only the optional pleasantness
/// question may say "feel", "pleasant" and "unpleasant" (decision D2); it is never shown back.
enum CheckInTexts {
    // MARK: Home (`V2-AccueilEnergie`)
    static let rowTitle = "Energy right now?"
    static let rowDetail = "Optional. Helps Harmony learn your usual."
    static func learning(answersThisWeek count: Int) -> String {
        "Harmony is learning your usual — \(count) \(count == 1 ? "answer" : "answers") this week"
    }

    // MARK: Sheet (`V2-CheckIn`)
    static let sheetTitle = "Energy right now"
    static let sheetText = "Your level right now. Your last answer is marked."
    static let last = "Last"
    static let low = "Low"
    static let high = "High"
    static let optional = "Optional"
    static let save = "Save"
    static let notNow = "Not now"
    /// The pleasantness question: the only place for "feel" and "pleasant" (D2).
    static let pleasantnessQuestion = "How does right now feel?"
    static let unpleasant = "Unpleasant"
    static let pleasant = "Pleasant"

    // MARK: Notification (`V2-Notification`)
    static let notification = "Quick check: energy right now?"
    static let medium = "Medium"

    // MARK: Onboarding (`V2-Onb4b-Questions`)
    static let onboardingTitle = "Two quick questions a day"
    static let onboardingText = "How much energy do you have right now? Your answers help Harmony learn your usual."
    static let onboardingTiles = [
        ("One tap", "Low, Medium or High, right from the notification."),
        ("Twice a day at most", "At a random time, in the hours you choose."),
        ("Always optional", "Ignore it or tap Not now. Harmony works without answers."),
        ("Stays on your phone", "Your answers never leave your iPhone."),
    ]
    static let onboardingNote = "Turn questions off anytime in Settings."
    static let allowNotifications = "Allow notifications"

    // MARK: Settings › Questions (`V2-Questions`, `V2-Reglages`)
    static let questions = "Questions"
    static let questionsText = "Two quick questions a day about your energy. Optional."
    static let questionsSwitch = "Up to 2 a day. Never in the hour after music."
    static let askBetween = "Ask me between"
    static let windowNames = ["Late morning", "Afternoon"]
    static let change = "Change"
    static let windowsText = "One question at a random time in each window."
    static let resetText = "Deletes your answers. Harmony goes back to its day-one estimate."
    static let reset = "Reset what Harmony learned"
    /// Not in the design: the system sheet that changes a window, and the reset confirmation.
    static let windowRule = "Between 07:00 and 22:00, at least one hour long."
    static let resetQuestion = "Reset what Harmony learned?"
    static let resetButton = "Reset"

    // MARK: My Data and About (`V2-MesDonnees`, `V2-APropos`)
    static let checkIns = "Check-ins"
    static let checkInsKept = "Check-ins are kept for 30 days."
    static let answersLabel = "Your answers"
    static let answersTune = "Your answers to the quick questions tune Harmony to you, on this iPhone only."
    static let answersFade = "Recent answers count most; older ones fade within a few days. Reset anytime in Settings › Questions."

    // MARK: What Harmony learned, in the "Your answers" card (`V2-APropos`, TODO 6.16)
    static let learnedMore = "Your answers show more energy than usual."
    static let learnedLess = "Your answers show less energy than usual."
    static let learnedSame = "No clear difference yet."
    static let learnedFew = "Not enough answers yet."
    static func curveAppears(soFar count: Int) -> String {
        "Your curve appears after \(LearnedCurve.minimumAnswers) answers. \(count) so far."
    }
    static let watchOnly = "Watch only"
    static let withYourAnswers = "With your answers"
    static let moreEnergy = "More energy"
    static let lessEnergy = "Less energy"
    static let yourUsual = "Your usual"
    static let twoWeeksAgo = "2 weeks ago"
    static let today = "Today"

    /// Every text above, for the forbidden-word test; `pleasantness` holds the D2 exceptions.
    static var all: [String] {
        [rowTitle, rowDetail, learning(answersThisWeek: 1), learning(answersThisWeek: 4), sheetTitle, sheetText, last,
         low, high, optional, save, notNow, notification, medium, onboardingTitle, onboardingText, onboardingNote,
         allowNotifications, questions, questionsText, questionsSwitch, askBetween, change, windowsText, resetText,
         reset, windowRule, resetQuestion, resetButton, checkIns, checkInsKept, answersLabel, answersTune, answersFade,
         learnedMore, learnedLess, learnedSame, learnedFew, curveAppears(soFar: 2), watchOnly, withYourAnswers,
         moreEnergy, lessEnergy, yourUsual, twoWeeksAgo, today]
            + onboardingTiles.flatMap { [$0.0, $0.1] } + windowNames
    }
    static let pleasantness = [pleasantnessQuestion, unpleasant, pleasant]
}
