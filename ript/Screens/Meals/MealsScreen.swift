import SwiftUI
import SwiftData

struct MealsScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                MealsContentView()
                    .padding()
            }
            .navigationTitle("Meals")
        }
    }
}

struct MealsContentView: View {
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SuggestedMealPlanSection(plan: suggestedPlan)
            
            FuelTodayCard(session: todaysSession, profile: fuelProfile)

            VStack(alignment: .leading, spacing: 12) {
                Text("Browse Options")
                    .font(.headline)

                if favoriteMeals.isEmpty == false {
                    MealLibrarySection(title: "Favorites", meals: favoriteMeals)
                }

                ForEach(categoryOrder, id: \.self) { category in
                    let categoryMeals = meals.filter { $0.category == category }
                    if categoryMeals.isEmpty == false {
                        MealLibrarySection(title: category, meals: categoryMeals)
                    }
                }
            }
        }
    }

    private var todaysSession: TrainingSession? {
        trainingSessions.first { Calendar.current.isDateInToday($0.date) }
    }

    private var fuelProfile: FuelProfile {
        FuelProfile.profile(for: todaysSession)
    }

    private var suggestedPlan: SuggestedMealPlan {
        SuggestedMealPlan.build(meals: meals, profile: fuelProfile, session: todaysSession)
    }

    private var favoriteMeals: [MealIdea] {
        meals.filter(\.isFavorite)
    }

    private var categoryOrder: [String] {
        ["Breakfast", "Lunch", "Dinner", "Snacks"]
    }
}
