import SwiftUI

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
