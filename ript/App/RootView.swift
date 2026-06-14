import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case workouts
    case wellness
    case coach
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @StateObject private var homeVM = HomeViewModel()
    @State private var selectedTab: AppTab = .home
    @State private var selectedWellnessSection: WellnessSection = .fuel

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(
                homeVM: homeVM,
                selectedTab: $selectedTab,
                selectedWellnessSection: $selectedWellnessSection
            )
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            WorkoutsScreen()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
                .tag(AppTab.workouts)
            WellnessScreen(selectedSection: $selectedWellnessSection)
                .tabItem { Label("Wellness", systemImage: "heart.text.square.fill") }
                .tag(AppTab.wellness)
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
