import SwiftUI
import SwiftData

enum WellnessSection: String, CaseIterable, Identifiable {
    case fuel = "Fuel"
    case journal = "Journal"

    var id: String { rawValue }
}

struct WellnessScreen: View {
    @Binding var selectedSection: WellnessSection
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]

    init(selectedSection: Binding<WellnessSection> = .constant(.fuel)) {
        _selectedSection = selectedSection
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WellnessSummaryCard(
                        session: todaysSession,
                        fuelProfile: fuelProfile,
                        reflection: todaysReflection
                    )

                    Picker("Wellness", selection: $selectedSection) {
                        ForEach(WellnessSection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    Group {
                        switch selectedSection {
                        case .fuel:
                            MealsContentView()
                        case .journal:
                            ReflectionContentView()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Wellness")
        }
    }

    private var todaysSession: TrainingSession? {
        trainingSessions.first { Calendar.current.isDateInToday($0.date) }
    }

    private var todaysReflection: Reflection? {
        reflections.first { Calendar.current.isDateInToday($0.date) }
    }

    private var fuelProfile: FuelProfile {
        FuelProfile.profile(for: todaysSession)
    }
}
#Preview {
    WellnessScreen()
}
