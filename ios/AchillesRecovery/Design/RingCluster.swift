import SwiftUI

struct RingSpec: Identifiable {
    let id = UUID()
    var value: Double   // 0...1
    var color: Color
    var label: String
    var display: String
    /// Optional target band on the track, as fractions of the ring (0...1).
    var band: ClosedRange<Double>?
}

/// Concentric activity rings, outermost first. The arc fills with a spring; reduced motion shows it instantly.
struct RingCluster<Center: View>: View {
    var rings: [RingSpec]
    var size: CGFloat = 220
    var stroke: CGFloat = 16
    var gap: CGFloat = 5
    @ViewBuilder var center: () -> Center

    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.element.id) { i, ring in
                let diameter = size - stroke - CGFloat(i) * 2 * (stroke + gap)
                if diameter > 0 {
                    Circle()
                        .stroke(ring.color.opacity(0.16), lineWidth: stroke)
                        .frame(width: diameter, height: diameter)
                    if let band = ring.band {
                        Circle()
                            .trim(from: min(max(band.lowerBound, 0), 1), to: min(max(band.upperBound, 0), 1))
                            .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                            .frame(width: diameter, height: diameter)
                            .rotationEffect(.degrees(-90))
                    }
                    Circle()
                        .trim(from: 0, to: min(max(ring.value, 0), 1) * progress)
                        .stroke(ring.color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        .frame(width: diameter, height: diameter)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: ring.color.opacity(0.55), radius: 6)
                }
            }
            center()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rings.map { "\($0.label) \($0.display)" }.joined(separator: ", "))
        .onAppear {
            if reduceMotion { progress = 1 } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { progress = 1 }
            }
        }
    }
}
