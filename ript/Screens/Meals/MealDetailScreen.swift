import SwiftUI
import SwiftData

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
