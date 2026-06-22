import SwiftUI
import SwiftData

@main
struct RiptApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [Day.self, Workout.self, TrainingPlan.self, TrainingSession.self, Reflection.self, BodyMetric.self, HealthDailySummary.self, HealthWorkout.self, MealIdea.self, Badge.self, CoachConversation.self, CoachMessage.self])
                .preferredColorScheme(.dark) // iPhone-first, dark mode friendly by default
        }
    }
}
