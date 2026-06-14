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

struct FuelTodayCard: View {
    var session: TrainingSession?
    var profile: FuelProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Fuel")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 14) {
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: profile.systemImage)
                        .font(.title2)
                        .foregroundStyle(profile.tint)
                        .frame(width: 34, height: 34)
                        .background(profile.tint.opacity(0.15), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(profile.title)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(session?.requiredSummary ?? "No scheduled workout found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(profile.guidance, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SuggestedMealPlanSection: View {
    var plan: SuggestedMealPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Plan")
                    .font(.headline)
            }

            VStack(spacing: 10) {
                ForEach(plan.items) { item in
                    if let meal = item.meal {
                        NavigationLink {
                            MealDetailScreen(meal: meal)
                        } label: {
                            SuggestedMealPlanRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SuggestedMealPlanRow(item: item)
                    }
                }
            }
        }
    }
}

struct SuggestedMealPlanRow: View {
    var item: SuggestedMealPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.subheadline)
                .foregroundStyle(item.tint)
                .frame(width: 30, height: 30)
                .background(item.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if item.meal?.isFavorite == true {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(item.meal?.title ?? item.fallbackTitle)
                    .font(.headline)

                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let meal = item.meal {
                    HStack(spacing: 10) {
                        Label("\(meal.proteinGrams)g", systemImage: "bolt.fill")
                        Label("\(meal.prepMinutes)m", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.meal != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealSuggestionSection: View {
    var title: String
    var subtitle: String
    var meals: [MealIdea]

    var body: some View {
        if meals.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(meals) { meal in
                        NavigationLink {
                            MealDetailScreen(meal: meal)
                        } label: {
                            MealIdeaRow(meal: meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct MealLibrarySection: View {
    var title: String
    var meals: [MealIdea]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(meals) { meal in
                    NavigationLink {
                        MealDetailScreen(meal: meal)
                    } label: {
                        MealIdeaRow(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct MealIdeaRow: View {
    var meal: MealIdea

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(meal.title)
                        .font(.headline)
                        .lineLimit(2)
                    if meal.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 10) {
                    Label("\(meal.proteinGrams)g", systemImage: "bolt.fill")
                    Label("\(meal.prepMinutes)m", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(meal.goalTags.prefix(3), id: \.self) { tag in
                        MealTagChip(title: tag)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealDetailScreen: View {
    @Environment(\.modelContext) private var context
    var meal: MealIdea

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(meal.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(meal.title)
                        .font(.largeTitle)
                        .bold()

                    HStack(spacing: 10) {
                        MealMetricCard(value: "\(meal.proteinGrams)g", label: "Protein")
                        MealMetricCard(value: "\(meal.prepMinutes)m", label: "Prep")
                    }

                    Text(meal.bestTiming)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(meal.goalTags, id: \.self) { tag in
                            MealTagChip(title: tag)
                        }
                    }
                }

                if meal.ingredients.isEmpty == false {
                    MealDetailBlock(title: "Ingredients", items: meal.ingredients)
                }

                if meal.steps.isEmpty == false {
                    MealDetailBlock(title: "Quick Prep", items: meal.steps)
                }

                if meal.notes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why It Fits")
                            .font(.headline)
                        Text(meal.notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                meal.isFavorite.toggle()
                try? context.save()
                Haptics.light()
            } label: {
                Image(systemName: meal.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(meal.isFavorite ? .yellow : .primary)
            }
            .accessibilityLabel(meal.isFavorite ? "Remove Favorite" : "Add Favorite")
        }
    }
}

struct MealMetricCard: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealDetailBlock: View {
    var title: String
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.08), in: Circle())
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MealTagChip: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.green)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.13), in: Capsule())
    }
}

struct FuelProfile {
    var title: String
    var systemImage: String
    var tint: Color
    var guidance: [String]
    var preWorkoutTags: Set<String>
    var postWorkoutTags: Set<String>

    static func profile(for session: TrainingSession?) -> FuelProfile {
        guard let session else {
            return FuelProfile(
                title: "Balanced Fuel Day",
                systemImage: "fork.knife",
                tint: .green,
                guidance: ["Protein every meal", "Build meals around lean protein and produce", "Use carbs around training when needed"],
                preWorkoutTags: ["Pre-Workout", "Quick"],
                postWorkoutTags: ["Post-Workout", "High Protein"]
            )
        }

        let segments = session.segments
        let hasRest = segments.contains { $0.kind == .rest }
        let hasBrick = segments.contains { $0.kind == .brick }
        let hasLongSession = segments.contains { segment in
            segment.title.localizedCaseInsensitiveContains("2 hr") ||
            segment.title.localizedCaseInsensitiveContains("90 min") ||
            segment.detail.localizedCaseInsensitiveContains("long")
        }
        let hasIntensity = segments.contains { segment in
            segment.detail.localizedCaseInsensitiveContains("hard") ||
            segment.detail.localizedCaseInsensitiveContains("tempo") ||
            segment.detail.localizedCaseInsensitiveContains("race pace") ||
            segment.detail.localizedCaseInsensitiveContains("faster")
        }

        if hasRest {
            return FuelProfile(
                title: "Recovery Fuel Day",
                systemImage: "leaf.fill",
                tint: .blue,
                guidance: ["Protein every meal", "Keep carbs moderate unless hunger is high", "Hydrate and keep meals simple"],
                preWorkoutTags: ["Lean", "High Protein", "No-Cook"],
                postWorkoutTags: ["High Protein", "Lean"]
            )
        }

        if hasBrick || hasLongSession {
            return FuelProfile(
                title: "Higher Carb Training Day",
                systemImage: "flame.fill",
                tint: .orange,
                guidance: ["Carbs before training", "Protein plus carbs after", "Use electrolytes for long bike or brick work"],
                preWorkoutTags: ["Pre-Workout", "High Carb", "Long Ride"],
                postWorkoutTags: ["Post-Workout", "High Protein", "High Carb"]
            )
        }

        if hasIntensity {
            return FuelProfile(
                title: "Quality Session Fuel",
                systemImage: "bolt.fill",
                tint: .yellow,
                guidance: ["Do not start hard work under-fueled", "Use easy carbs before training", "Recover with protein plus carbs"],
                preWorkoutTags: ["Pre-Workout", "Quick", "High Carb"],
                postWorkoutTags: ["Post-Workout", "High Protein"]
            )
        }

        return FuelProfile(
            title: "Balanced Fuel Day",
            systemImage: "fork.knife",
            tint: .green,
            guidance: ["Protein every meal", "Add carbs near swim, bike, or run", "Keep dinner lean and filling"],
            preWorkoutTags: ["Pre-Workout", "Quick"],
            postWorkoutTags: ["Post-Workout", "High Protein", "Lean"]
        )
    }
}

struct SuggestedMealPlan {
    var items: [SuggestedMealPlanItem]

    static func build(meals: [MealIdea], profile: FuelProfile, session: TrainingSession?) -> SuggestedMealPlan {
        let isRestDay = session?.segments.contains { $0.kind == .rest } ?? false
        let isLongDay = profile.preWorkoutTags.contains("Long Ride")
        let isCarbDay = profile.preWorkoutTags.contains("High Carb")
        var usedIDs = Set<UUID>()

        func take(title: String? = nil, category: String? = nil, preferredTags: [String]) -> MealIdea? {
            let candidates = meals.filter { meal in
                let matchesCategory = category.map { meal.category == $0 } ?? true
                return matchesCategory && usedIDs.contains(meal.id) == false
            }

            if let title, let exact = candidates.first(where: { $0.title == title }) {
                usedIDs.insert(exact.id)
                return exact
            }

            let ranked = candidates.sorted { lhs, rhs in
                let lhsScore = lhs.score(for: preferredTags)
                let rhsScore = rhs.score(for: preferredTags)
                if lhsScore == rhsScore { return lhs.title < rhs.title }
                return lhsScore > rhsScore
            }

            guard let chosen = ranked.first else { return nil }
            usedIDs.insert(chosen.id)
            return chosen
        }

        let breakfast = take(
            title: isCarbDay ? "Protein oats" : nil,
            category: "Breakfast",
            preferredTags: isCarbDay ? ["High Carb", "Pre-Workout", "High Protein"] : ["High Protein", "Lean", "Quick"]
        )
        let lunch = take(
            title: isCarbDay ? "Chicken rice bowl" : "Turkey sandwich",
            category: "Lunch",
            preferredTags: isCarbDay ? ["Post-Workout", "High Carb", "High Protein"] : ["High Protein", "Quick", "Lean"]
        )
        let dinner = take(
            title: isLongDay || isCarbDay ? "Chicken + rice" : "Salmon + sweet potato",
            category: "Dinner",
            preferredTags: isCarbDay ? ["Post-Workout", "High Carb", "High Protein"] : ["Lean", "High Protein"]
        )
        let snack = take(
            title: isCarbDay ? "Banana + peanut butter toast" : "Cottage cheese bowl",
            category: "Snacks",
            preferredTags: isCarbDay ? ["Pre-Workout", "High Carb", "Quick"] : ["High Protein", "Lean", "No-Cook"]
        )
        let sessionFuel = isRestDay ? nil : take(
            title: isLongDay ? "Electrolyte carb bottle" : nil,
            category: "Snacks",
            preferredTags: isLongDay ? ["Long Ride", "High Carb"] : ["Pre-Workout", "Quick", "High Carb"]
        )

        let sessionFuelTitle = isRestDay ? "Hydration + normal meals" : "Pick quick training fuel"
        let sessionFuelNote = if isRestDay {
            "No extra workout fuel needed today."
        } else if isLongDay {
            "Use this around the long bike or brick."
        } else {
            "Use this before training if your last meal was light."
        }

        return SuggestedMealPlan(items: [
            SuggestedMealPlanItem(title: "Breakfast", fallbackTitle: "Pick a protein-forward breakfast", note: isCarbDay ? "Start with protein plus easy carbs." : "Keep it filling and protein-forward.", systemImage: "sun.max.fill", tint: .yellow, meal: breakfast),
            SuggestedMealPlanItem(title: "Lunch", fallbackTitle: "Pick a high-protein lunch", note: isCarbDay ? "Recover with carbs and lean protein." : "Stay steady without overcomplicating it.", systemImage: "fork.knife", tint: .green, meal: lunch),
            SuggestedMealPlanItem(title: "Dinner", fallbackTitle: "Pick a lean dinner", note: isCarbDay ? "Refill glycogen without making dinner chaotic." : "Lean protein, produce, and enough carbs for recovery.", systemImage: "moon.fill", tint: .indigo, meal: dinner),
            SuggestedMealPlanItem(title: "Snack", fallbackTitle: "Pick a simple snack", note: isCarbDay ? "Use this as a bridge into training." : "Easy protein without much prep.", systemImage: "takeoutbag.and.cup.and.straw.fill", tint: .mint, meal: snack),
            SuggestedMealPlanItem(title: "Session Fuel", fallbackTitle: sessionFuelTitle, note: sessionFuelNote, systemImage: isRestDay ? "drop.fill" : "bolt.fill", tint: profile.tint, meal: sessionFuel)
        ])
    }
}

struct SuggestedMealPlanItem: Identifiable {
    var id: String { title }
    var title: String
    var fallbackTitle: String
    var note: String
    var systemImage: String
    var tint: Color
    var meal: MealIdea?
}

private extension Array where Element == MealIdea {
    func matching(tags: Set<String>, limit: Int) -> [MealIdea] {
        filter { meal in
            tags.isDisjoint(with: Set(meal.goalTags)) == false
        }
        .prefix(limit)
        .map { $0 }
    }
}

private extension MealIdea {
    func score(for preferredTags: [String]) -> Int {
        preferredTags.reduce(isFavorite ? 1 : 0) { score, tag in
            goalTags.contains(tag) ? score + 1 : score
        }
    }
}

// MARK: - Reflection
