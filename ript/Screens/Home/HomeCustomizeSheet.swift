import SwiftUI

enum HomeCardKind: String, CaseIterable, Identifiable {
    case score
    case todaysPlan
    case nextAction
    case momentum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .score:
            return "Daily Progress"
        case .todaysPlan:
            return "Today's Plan"
        case .nextAction:
            return "Next Action"
        case .momentum:
            return "Momentum"
        }
    }

    var systemImage: String {
        switch self {
        case .score:
            return "chart.line.uptrend.xyaxis"
        case .todaysPlan:
            return "calendar"
        case .nextAction:
            return "arrow.right.circle.fill"
        case .momentum:
            return "flame.fill"
        }
    }

    static func cards(from storage: String) -> [HomeCardKind] {
        var cards: [HomeCardKind] = []

        for rawValue in storage.split(separator: ",").map(String.init) {
            guard let card = HomeCardKind(rawValue: rawValue), cards.contains(card) == false else { continue }
            cards.append(card)
        }

        for card in allCases where cards.contains(card) == false {
            cards.append(card)
        }

        return cards
    }

    static func storageValue(for cards: [HomeCardKind]) -> String {
        cards.map(\.rawValue).joined(separator: ",")
    }
}

struct HomeCustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [HomeCardKind]
    let onSave: ([HomeCardKind]) -> Void

    init(cards: [HomeCardKind], onSave: @escaping ([HomeCardKind]) -> Void) {
        _cards = State(initialValue: cards)
        self.onSave = onSave
    }

    var body: some View {
        List {
            Section {
                ForEach(cards) { card in
                    Label(card.title, systemImage: card.systemImage)
                }
                .onMove { source, destination in
                    cards.move(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Customize Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Reset") {
                    cards = HomeCardKind.allCases
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    onSave(cards)
                    dismiss()
                }
            }
        }
    }
}
