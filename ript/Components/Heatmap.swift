import SwiftUI

struct Heatmap: View {
    var values: [Date: Int] // 0..n per day
    var body: some View {
        let days = (0..<42).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }.reversed()
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { d in
                let v = values[Calendar.current.startOfDay(for: d)] ?? 0
                Rectangle()
                    .fill(Color.green.opacity(min(0.1 + Double(v) * 0.2, 1)))
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}
