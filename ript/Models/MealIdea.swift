import Foundation
import SwiftData

// MARK: - Meal Idea (SwiftData)
@Model
final class MealIdea {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String // Breakfast, Lunch, Dinner, Snacks
    var proteinGrams: Int = 0
    var prepMinutes: Int = 0
    var goalTags: [String] = []
    var ingredients: [String] = []
    var steps: [String] = []
    var bestTiming: String = ""
    var notes: String = ""
    var isFavorite: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        proteinGrams: Int = 0,
        prepMinutes: Int = 0,
        goalTags: [String] = [],
        ingredients: [String] = [],
        steps: [String] = [],
        bestTiming: String = "",
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.proteinGrams = proteinGrams
        self.prepMinutes = prepMinutes
        self.goalTags = goalTags
        self.ingredients = ingredients
        self.steps = steps
        self.bestTiming = bestTiming
        self.notes = notes
        self.isFavorite = isFavorite
    }
}
