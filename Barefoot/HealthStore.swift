import HealthKit

final class HealthStore {
    private let store = HKHealthStore()
    private let mass = HKQuantityType(.bodyMass)

    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [mass], read: [])
    }

    func save(kg: Double, at date: Date) async throws {
        let sample = HKQuantitySample(
            type: mass,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date
        )
        try await store.save(sample)
    }
}
