import SwiftUI

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

extension Array where Element == MealIdea {
    func matching(tags: Set<String>, limit: Int) -> [MealIdea] {
        filter { meal in
            tags.isDisjoint(with: Set(meal.goalTags)) == false
        }
        .prefix(limit)
        .map { $0 }
    }
}

extension MealIdea {
    func score(for preferredTags: [String]) -> Int {
        preferredTags.reduce(isFavorite ? 1 : 0) { score, tag in
            goalTags.contains(tag) ? score + 1 : score
        }
    }
}

// MARK: - Reflection
