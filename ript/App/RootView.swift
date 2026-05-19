import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case workouts
    case meals
    case reflect
    case coach
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @StateObject private var appVM = AppViewModel()
    @StateObject private var homeVM = HomeViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(appVM: appVM, homeVM: homeVM, selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            WorkoutsScreen()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
                .tag(AppTab.workouts)
            MealsScreen()
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(AppTab.meals)
            ReflectionScreen()
                .tabItem { Label("Reflect", systemImage: "moon.stars.fill") }
                .tag(AppTab.reflect)
            CoachScreen()
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(AppTab.coach)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            SampleDataSeeder.seed(context: context)
            await NotificationScheduler.requestAuthorization()
            NotificationScheduler.scheduleDailyReminders()
        }
    }
}
