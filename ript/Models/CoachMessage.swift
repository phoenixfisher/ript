import Foundation
import SwiftData

// MARK: - Coach Chat (SwiftData)
@Model
final class CoachMessage {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var role: String
    var content: String
    var conversationID: UUID?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        role: String,
        content: String,
        conversationID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.role = role
        self.content = content
        self.conversationID = conversationID
    }
}
