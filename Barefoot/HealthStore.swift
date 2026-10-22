import HealthKit

@MainActor
final class HealthStore: ObservableObject {
    /// Most recent weigh-ins, newest first. Read back only to draw the trend.
    @Published private(set) var history: [(date: Date, kg: Double)] = []

    private let store = HKHealthStore()
    private let mass = HKQuantityType(.bodyMass)

    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [mass], read: [mass])
        await load()
    }

    func load(days: Int = 14) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let samples: [HKQuantitySample] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: mass,
                predicate: predicate,
                limit: 500,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, result, _ in
                cont.resume(returning: result as? [HKQuantitySample] ?? [])
            }
            store.execute(query)
        }
        history = samples.map { ($0.endDate, $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }

    func save(kg: Double, at date: Date) async throws {
        let sample = HKQuantitySample(
            type: mass,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date
        )
        try await store.save(sample)
        await load()
    }
}
