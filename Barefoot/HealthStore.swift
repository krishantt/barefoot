import HealthKit

@MainActor
final class HealthStore: ObservableObject {
    /// One reading per day, oldest first. Read back only to draw the trend.
    @Published private(set) var history: [(date: Date, kg: Double)] = []
    /// The unit the user picked in Apple Health, so we show lb if that is their setting.
    @Published private(set) var usesPounds = Locale.current.measurementSystem == .us

    private let store = HKHealthStore()
    private let mass = HKQuantityType(.bodyMass)

    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [mass], read: [mass])
        let units = try? await store.preferredUnits(for: [mass])
        if let unit = units?[mass], unit == HKUnit.pound() {
            usesPounds = true
        } else if let unit = units?[mass], unit == HKUnit.gramUnit(with: .kilo) {
            usesPounds = false
        }
        await load()
    }

    func load(days: Int = 14) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let samples = await fetch(predicate)

        // Collapse to one point per day, keeping the latest: two weigh-ins on the
        // same day would otherwise stack on the same x position.
        var byDay: [Date: Double] = [:]
        for sample in samples {
            byDay[Calendar.current.startOfDay(for: sample.endDate)] =
                sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        }
        history = byDay.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Screenshot/demo only: in-memory points for the trend card. Nothing is
    /// written to Health.
    func seedDemoHistory() {
        let now = Date()
        history = (0..<14).reversed().compactMap { offset in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return (day, 68.4 + Double(offset) * 0.12)
        }
    }

    func save(kg: Double, at date: Date) async throws {
        // The scale repeats its settled frame; never write the same weigh-in twice,
        // including across app restarts.
        if await alreadySaved(kg: kg, near: date) { return }

        let sample = HKQuantitySample(
            type: mass,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date
        )
        try await store.save(sample)
        await load()
    }

    private func alreadySaved(kg: Double, near date: Date) async -> Bool {
        let window = date.addingTimeInterval(-120)
        let predicate = HKQuery.predicateForSamples(withStart: window,
                                                    end: date.addingTimeInterval(120))
        return await fetch(predicate).contains {
            abs($0.quantity.doubleValue(for: .gramUnit(with: .kilo)) - kg) < 0.05
        }
    }

    private func fetch(_ predicate: NSPredicate) async -> [HKQuantitySample] {
        await withCheckedContinuation { cont in
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
    }
}
