import Foundation
import SwiftData

// MARK: - Coach Chat (SwiftData)
@Model
final class CoachMessage {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var role: String
    var content: String

    init(id: UUID = UUID(), createdAt: Date = Date(), role: String, content: String) {
        self.id = id
        self.createdAt = createdAt
        self.role = role
        self.content = content
    }
}
