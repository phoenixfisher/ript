import Foundation
import SwiftData

// MARK: - Badge (SwiftData)
@Model
final class Badge {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String
    var unlockedOn: Date?

    init(id: UUID = UUID(), name: String, detail: String, unlockedOn: Date? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.unlockedOn = unlockedOn
    }
}
