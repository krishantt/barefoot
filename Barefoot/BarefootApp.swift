import SwiftUI
import UIKit

@main
struct BarefootApp: App {
    @StateObject private var scale = ScaleClient()
    @StateObject private var health = HealthStore()

    var body: some Scene {
        WindowGroup {
            ContentView(scale: scale, health: health)
                .task {
                    scale.onStableWeight = { kg, date in
                        Task {
                            do {
                                try await health.save(kg: kg, at: date)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                await MainActor.run { scale.savedAt = Date() }
                            } catch {
                                await MainActor.run { scale.status = "Health save failed" }
                            }
                        }
                    }

                    // -demo: App Store screenshots and UI checks without a scale
                    // or a Health permission prompt.
                    if ProcessInfo.processInfo.arguments.contains("-demo") {
                        scale.demo()
                        health.seedDemoHistory()
                    } else {
                        try? await health.authorize()
                    }
                }
        }
    }
}
