import Foundation

enum SettingsDestructiveAction {
    case resetTrainingPlan
    case clearCoachMessages
    case clearJournalEntries
    case resetAllLocalData

    var title: String {
        switch self {
        case .resetTrainingPlan:
            return "Reset generated plan?"
        case .clearCoachMessages:
            return "Clear coach chats?"
        case .clearJournalEntries:
            return "Clear journal entries?"
        case .resetAllLocalData:
            return "Delete and reset app data?"
        }
    }

    var message: String {
        switch self {
        case .resetTrainingPlan:
            return "This replaces the generated training sessions with the default Olympic triathlon plan."
        case .clearCoachMessages:
            return "This removes all coach conversations and messages from this device."
        case .clearJournalEntries:
            return "This removes all reflect/journal entries from this device."
        case .resetAllLocalData:
            return "This deletes local progress, workouts, meals, journal entries, coach messages, and generated plan data, then reloads the default seeded content."
        }
    }

    var buttonTitle: String {
        switch self {
        case .resetTrainingPlan:
            return "Reset Plan"
        case .clearCoachMessages:
            return "Clear Chats"
        case .clearJournalEntries:
            return "Clear Journal"
        case .resetAllLocalData:
            return "Delete and Reset"
        }
    }
}
