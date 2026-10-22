import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var scale: ScaleClient
    @ScaledMetric(relativeTo: .largeTitle) private var weightSize: CGFloat = 84
    @Environment(\.openURL) private var openURL

    private var usesPounds: Bool { Locale.current.measurementSystem == .us }
    private var unitName: String { usesPounds ? "lb" : "kg" }

    private func display(_ kg: Double) -> String {
        String(format: "%.1f", usesPounds ? kg * 2.2046226218 : kg)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(scale.weightKg.map(display) ?? "—")
                .font(.system(size: weightSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .accessibilityLabel("Weight")
                .accessibilityValue(scale.weightKg.map { "\(display($0)) \(unitName)" } ?? "no reading yet")

            Text(unitName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(scale.status)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let saved = scale.savedAt {
                Label("Saved to Health \(saved.formatted(date: .omitted, time: .shortened))",
                      systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            Spacer()

            Text(scale.lastPacket.isEmpty ? "no data yet" : scale.lastPacket)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .padding(.horizontal)
                .accessibilityLabel("Last Bluetooth frame")

            if scale.bluetoothBlocked {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                Button("Scan again") { scale.rescan() }
                Button("Demo") { scale.demo() }
                    .accessibilityHint("Shows a sample reading without a scale")
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 32)
        }
    }
}
