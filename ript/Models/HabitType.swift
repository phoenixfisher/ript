import Foundation

// MARK: - HabitType
enum HabitType: String, Codable, CaseIterable, Identifiable {
    case gotUpImmediately = "Got up immediately"
    case proteinEveryMeal = "Protein every meal"
    case stoppedAtNotHungry = "Stopped eating at not hungry"
    case coreOrWorkout = "Core or workout"
    case intentionalTreat = "One intentional treat"

    var id: String { rawValue }

    var xpReward: Int {
        switch self {
        case .gotUpImmediately: return 15
        case .proteinEveryMeal: return 20
        case .stoppedAtNotHungry: return 15
        case .coreOrWorkout: return 30
        case .intentionalTreat: return 10
        }
    }
}
