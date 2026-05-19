import Foundation
internal import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyQuote: String = HomeViewModel.randomQuote()

    private static let quoteBank = [
        "Win the first 10 seconds.",
        "Small wins. Big results.",
        "Show up. Then show off.",
        "Discipline beats motivation.",
        "Consistency compounds.",
        "Earn confidence one rep at a time.",
        "Start before you feel ready.",
        "Make the next choice clean.",
        "Keep promises to yourself.",
        "Do the work you planned.",
        "Strong habits beat strong moods.",
        "Train today like it counts.",
        "Fuel the body you are building.",
        "The easy skip is still a choice.",
        "Stack the basics.",
        "Finish the small thing.",
        "Make discipline automatic.",
        "Better shape starts with better reps.",
        "One clean day is momentum.",
        "Stay ready for the next session.",
        "Progress likes repetition.",
        "Control the controllables.",
        "Abs show up after consistency.",
        "No wasted workouts.",
        "Build the engine and the frame.",
        "Make recovery part of the plan.",
        "Today's effort buys tomorrow's options.",
        "Win the meal in front of you.",
        "Train hard. Recover harder.",
        "Simple done beats perfect skipped.",
        "The plan works when you do.",
        "Protect the streak with one action.",
        "Every checkmark is evidence.",
        "Lift with intent.",
        "Run the day, then log it.",
        "You only need the next rep.",
        "Sharp choices create sharp results.",
        "Eat for the session ahead.",
        "Your future body is built today.",
        "Be the person who follows through.",
        "Do not negotiate with the checklist.",
        "Keep the floor high.",
        "Train the body. Practice the identity.",
        "Move with purpose.",
        "Hard days count double.",
        "Make the ordinary work obvious.",
        "Stay patient. Stay precise.",
        "The mirror follows the routine.",
        "One more honest day.",
        "Work first. Pride after.",
        "Consistency is a physique skill.",
        "Strong today, sharper tomorrow.",
        "Make your default disciplined.",
        "Earn the next level.",
        "Let the plan carry you.",
        "Good enough done every day wins."
    ]

    static func randomQuote(excluding currentQuote: String? = nil) -> String {
        let candidates = quoteBank.filter { $0 != currentQuote }
        return (candidates.randomElement() ?? quoteBank.randomElement()) ?? "Win the first 10 seconds."
    }

    func resetQuote() {
        dailyQuote = Self.randomQuote(excluding: dailyQuote)
    }
}
