import Foundation

/// Run/walk intervals by distance, for example run 0.3 mi, walk 0.1 mi, 4 rounds.
struct RunPlan: Codable, Equatable {
    static let metersPerMile = 1609.344

    var runMiles = 0.3
    /// Zero means no walk breaks.
    var walkMiles = 0.1
    var rounds = 4

    var runMeters: Double { runMiles * Self.metersPerMile }
    var walkMeters: Double { walkMiles * Self.metersPerMile }
    var totalMiles: Double { Double(rounds) * (runMiles + walkMiles) }
}

struct RunSegment: Codable, Equatable {
    /// Cooldown is whatever you cover after the last planned round.
    enum Kind: String, Codable { case run, walk, cooldown }

    var kind: Kind
    var meters: Double
    var seconds: Double
}

/// Walks a plan forward as distance comes in. No clocks or GPS in here, so it can be unit tested.
struct RunEngine {
    enum Event: Equatable {
        case run(round: Int)
        case walk
        case planComplete
    }

    let plan: RunPlan
    private(set) var completed: [RunSegment] = []
    private(set) var kind: RunSegment.Kind = .run
    private(set) var round = 1
    private(set) var segmentMeters = 0.0
    private(set) var totalMeters = 0.0
    private var segmentStart: TimeInterval = 0

    init(plan: RunPlan) { self.plan = plan }

    /// Length of the current interval. Nil once the plan is done.
    var target: Double? {
        switch kind {
        case .run: max(plan.runMeters, 1)
        case .walk: max(plan.walkMeters, 1)
        case .cooldown: nil
        }
    }

    var remaining: Double? { target.map { max($0 - segmentMeters, 0) } }
    var progress: Double { target.map { min(segmentMeters / $0, 1) } ?? 1 }
    var planComplete: Bool { kind == .cooldown }

    func segmentSeconds(elapsed: TimeInterval) -> TimeInterval { max(elapsed - segmentStart, 0) }

    /// Adds distance covered. `elapsed` is active seconds since the run began. Returns the interval changes it caused.
    mutating func advance(meters: Double, elapsed: TimeInterval) -> [Event] {
        var events: [Event] = []
        totalMeters += meters
        segmentMeters += meters
        while let target, segmentMeters >= target {
            let carry = segmentMeters - target
            completed.append(RunSegment(kind: kind, meters: target, seconds: segmentSeconds(elapsed: elapsed)))
            segmentStart = elapsed
            segmentMeters = carry
            if kind == .run && plan.walkMeters > 0 {
                kind = .walk
                events.append(.walk)
            } else if round >= plan.rounds {
                kind = .cooldown
                events.append(.planComplete)
            } else {
                round += 1
                kind = .run
                events.append(.run(round: round))
            }
        }
        return events
    }

    /// Every segment, including the one in progress.
    func segments(elapsed: TimeInterval) -> [RunSegment] {
        let open = RunSegment(kind: kind, meters: segmentMeters, seconds: segmentSeconds(elapsed: elapsed))
        return open.meters > 0 ? completed + [open] : completed
    }
}

/// Turns raw GPS fixes into distance, dropping fixes that are inaccurate, jittery or impossible.
struct GPSFilter {
    struct Sample: Equatable {
        var lat: Double
        var lon: Double
        /// Horizontal accuracy in metres. Negative means invalid.
        var accuracy: Double
        var time: TimeInterval
    }

    static let maxAccuracy = 25.0
    /// Below this, movement is treated as GPS noise. The anchor stays put, so slow walking still adds up.
    static let minStep = 3.0
    /// About 3:35 per mile. Faster than that is a GPS jump.
    static let maxSpeed = 7.5

    private(set) var anchor: Sample?

    /// Forget the last position (after a pause, so the gap is not counted).
    mutating func reset() { anchor = nil }

    static func isUsable(_ s: Sample) -> Bool { s.accuracy >= 0 && s.accuracy <= maxAccuracy }

    /// Metres to add for this fix, or nil if the fix was dropped. The first good fix returns 0.
    mutating func accept(_ s: Sample) -> Double? {
        guard Self.isUsable(s) else { return nil }
        guard let last = anchor else { anchor = s; return 0 }
        let dt = s.time - last.time
        guard dt > 0 else { return nil }
        let d = Self.distance(last, s)
        guard d >= Self.minStep, d / dt <= Self.maxSpeed else { return nil }
        anchor = s
        return d
    }

    /// Haversine distance in metres.
    static func distance(_ a: Sample, _ b: Sample) -> Double {
        let r = 6_371_000.0
        let p1 = a.lat * .pi / 180, p2 = b.lat * .pi / 180
        let dp = p2 - p1, dl = (b.lon - a.lon) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}

enum RunFormat {
    static func miles(_ meters: Double) -> String {
        String(format: "%.2f", meters / RunPlan.metersPerMile)
    }

    /// Plan distances: "0.3", "0.25", "1".
    static func planMiles(_ miles: Double) -> String {
        let s = String(format: "%.2f", miles)
        let trimmed = s.hasSuffix("0") ? String(s.dropLast()) : s
        return trimmed.hasSuffix(".0") ? String(trimmed.dropLast(2)) : trimmed
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Minutes per mile, or "--" until there is enough distance to be meaningful.
    static func pace(meters: Double, seconds: Double) -> String {
        guard meters >= 20, seconds > 0 else { return "--" }
        let perMile = seconds / (meters / RunPlan.metersPerMile)
        guard perMile < 3600 else { return "--" }
        return String(format: "%d:%02d", Int(perMile) / 60, Int(perMile) % 60)
    }
}
