import SwiftUI

/// The glass look shared by both Live Activities: a see-through card, glossy fills and sunken tracks.
enum Glass {
    /// Card tint. Left see-through so the system blurs the wallpaper behind it.
    static let card = Aurora.card.opacity(0.72)
    /// Secondary text. Lighter than `textMuted` so it stays readable over a bright wallpaper.
    static let muted = Color(hex: 0xA9B4CF)
}

extension RunSegment.Kind {
    var activityTint: Color {
        switch self {
        case .run: Aurora.strain
        case .walk: Aurora.recovery
        case .cooldown: Aurora.sleepInk
        }
    }

    var activityTitle: String {
        switch self {
        case .run: "Run"
        case .walk: "Walk"
        case .cooldown: "Cool down"
        }
    }
}

extension View {
    /// Uppercase status label in the metric's colour.
    func statusLabel(_ tint: Color) -> some View {
        font(.system(size: 12, weight: .semibold)).tracking(0.7).textCase(.uppercase).foregroundStyle(tint)
    }
}

/// A filled shape with a lit top edge and a shaded underside, so it reads as a glass bead or tube.
struct Glossy<S: InsettableShape>: View {
    var shape: S
    var tint: Color
    var glow = true

    var body: some View {
        shape
            .fill(tint.shadow(.inner(color: .white.opacity(0.55), radius: 0.5, y: 2)).shadow(.inner(color: .black.opacity(0.3), radius: 2, y: -3)))
            .shadow(color: glow ? tint.opacity(0.5) : .clear, radius: 6)
    }
}

/// The empty groove a glossy fill sits in.
struct Groove<S: InsettableShape>: View {
    var shape: S
    var tint: Color

    var body: some View {
        shape.fill(tint.opacity(0.16).shadow(.inner(color: .black.opacity(0.55), radius: 1.5, y: 2)))
    }
}

/// Small glowing dot in front of a status label.
struct StatusBead: View {
    var tint: Color

    var body: some View {
        Glossy(shape: Circle(), tint: tint).frame(width: 10, height: 10).accessibilityHidden(true)
    }
}

/// The run plan as a segmented glass tube.
struct PlanRailView: View {
    var segments: [PlanRail.Segment]
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = segments.count > 16 ? 2 : 4
            let total = max(segments.reduce(0) { $0 + $1.weight }, 1)
            let usable = max(geo.size.width - spacing * CGFloat(max(segments.count - 1, 0)), 0)
            HStack(spacing: spacing) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let width = usable * segment.weight / total
                    ZStack(alignment: .leading) {
                        Groove(shape: Capsule(), tint: segment.kind.activityTint)
                        if segment.fill > 0 {
                            Glossy(shape: Capsule(), tint: segment.kind.activityTint, glow: segment.fill < 1)
                                .frame(width: max(width * segment.fill, min(height, width)))
                        }
                    }
                    .frame(width: width, height: height)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Tiny progress ring for the Dynamic Island.
struct MiniRing: View {
    var progress: Double
    var tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: 4)
            Circle().trim(from: 0, to: min(max(progress, 0.02), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
