import Foundation
import SwiftUI
import UserNotifications
import SwiftData

enum Haptics {
    static func success() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

struct NotificationScheduler {
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleDailyReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let items: [(String, Int, Int)] = [
            ("Win the first 10 seconds.", 6, 0),
            ("Did you win today?", 22, 30)
        ]

        for (body, hour, minute) in items {
            let content = UNMutableNotificationContent()
            content.title = "Ript"
            content.body = body
            var date = DateComponents()
            date.hour = hour
            date.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }
}

struct SampleDataSeeder {
    static func seed(context: ModelContext) {
        // Only seed if empty
        let fetch = FetchDescriptor<Workout>()
        if (try? context.fetch(fetch))?.isEmpty == false { return }

        // Workouts
        let athleteCore = Workout(name: "Athlete Core", exercises: [
            Exercise(name: "Leg Raises", sets: 3, repsDescription: "10-15 reps"),
            Exercise(name: "Plank", sets: 3, repsDescription: "45-60s"),
            Exercise(name: "Crunches", sets: 3, repsDescription: "15-20 reps")
        ])
        let quickHome = Workout(name: "Quick Home Workout", exercises: [
            Exercise(name: "Push-ups", sets: 3, repsDescription: "10-20 reps"),
            Exercise(name: "Air Squats", sets: 3, repsDescription: "20 reps"),
            Exercise(name: "Mountain Climbers", sets: 3, repsDescription: "30s")
        ])
        let push = Workout(name: "Gym Push Day", exercises: [
            Exercise(name: "Bench Press", sets: 4, repsDescription: "5-8 reps"),
            Exercise(name: "Incline DB Press", sets: 3, repsDescription: "8-12 reps"),
            Exercise(name: "Tricep Pushdown", sets: 3, repsDescription: "10-15 reps")
        ])
        let pull = Workout(name: "Gym Pull Day", exercises: [
            Exercise(name: "Deadlift", sets: 3, repsDescription: "3-5 reps"),
            Exercise(name: "Lat Pulldown", sets: 3, repsDescription: "8-12 reps"),
            Exercise(name: "DB Row", sets: 3, repsDescription: "8-12 reps")
        ])
        context.insert(athleteCore)
        context.insert(quickHome)
        context.insert(push)
        context.insert(pull)

        // Meals
        [
            ("Greek yogurt + fruit", "Breakfast"),
            ("Eggs + toast", "Breakfast"),
            ("Turkey sandwich", "Lunch"),
            ("Chicken + rice", "Dinner"),
            ("Protein shake", "Snacks")
        ].forEach { title, category in
            context.insert(MealIdea(title: title, category: category))
        }

        try? context.save()
    }
}
