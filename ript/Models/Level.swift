import Foundation

// MARK: - Level System
struct Level: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let requiredXP: Int
}

let defaultLevels: [Level] = [
    .init(id: 1, title: "Getting Started", requiredXP: 0),
    .init(id: 2, title: "Locked In", requiredXP: 200),
    .init(id: 3, title: "Discipline Builder", requiredXP: 600),
    .init(id: 4, title: "Shirt-Off Confidence", requiredXP: 1200)
]
