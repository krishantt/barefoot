import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var scale: ScaleClient
    @ObservedObject var health: HealthStore
    @ScaledMetric(relativeTo: .largeTitle) private var weightSize: CGFloat = 96
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesPounds: Bool { Locale.current.measurementSystem == .us }
    private var unitName: String { usesPounds ? "lb" : "kg" }

    private func display(_ kg: Double) -> String {
        String(format: "%.1f", usesPounds ? kg * 2.2046226218 : kg)
    }

    private var trend: [Double] {
        health.history.map(\.kg)
    }

    private var delta: Double? {
        guard let first = trend.first, let last = trend.last, trend.count > 1 else { return nil }
        return last - first
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.71, blue: 0.68),
                                    Color(red: 0.07, green: 0.29, blue: 0.50)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 4) {
                    Text(scale.weightKg.map(display) ?? "—")
                        .font(.system(size: weightSize, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .snappy, value: scale.weightKg)
                        .accessibilityLabel("Weight")
                        .accessibilityValue(scale.weightKg.map { "\(display($0)) \(unitName)" } ?? "no reading yet")

                    Text(unitName)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityHidden(true)
                }

                if trend.count > 1, let delta {
                    trendCard(delta: delta)
                }

                Spacer()

                VStack(spacing: 10) {
                    if let saved = scale.savedAt {
                        Label("Saved to Health \(saved.formatted(date: .omitted, time: .shortened))",
                              systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    Text(scale.status)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(scale.lastPacket.isEmpty ? "no data yet" : scale.lastPacket)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .accessibilityLabel("Last Bluetooth frame")
                }

                controls
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
    }

    private func trendCard(delta: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 14 days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(deltaString(delta))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Sparkline(values: trend)
                .frame(height: 56)
                .accessibilityLabel("Weight trend over the last 14 days")
                .accessibilityValue(deltaString(delta))
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func deltaString(_ kg: Double) -> String {
        let value = usesPounds ? kg * 2.2046226218 : kg
        let sign = value > 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(value))) \(unitName)"
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if scale.bluetoothBlocked {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color(red: 0.07, green: 0.29, blue: 0.50))
            }

            HStack(spacing: 12) {
                Button("Scan again") { scale.rescan() }
                Button("Demo") { scale.demo() }
                    .accessibilityHint("Shows a sample reading without a scale")
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .foregroundStyle(.white)
        }
    }
}

private struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = max(hi - lo, 0.4)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((value - lo) / span))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}
