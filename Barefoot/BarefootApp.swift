import SwiftUI

@main
struct BarefootApp: App {
    @StateObject private var scale = ScaleClient()
    private let health = HealthStore()

    var body: some Scene {
        WindowGroup {
            ContentView(scale: scale)
                .task {
                    try? await health.authorize()
                    scale.onStableWeight = { kg, date in
                        Task {
                            do {
                                try await health.save(kg: kg, at: date)
                                await MainActor.run { scale.savedAt = Date() }
                            } catch {
                                await MainActor.run { scale.status = "Health save failed" }
                            }
                        }
                    }
                }
        }
    }
}
