import SwiftUI

struct ChecklistRow: View {
    var title: String
    var isChecked: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .symbolEffect(.bounce, value: isChecked)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
