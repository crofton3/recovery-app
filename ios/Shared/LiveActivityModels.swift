import ActivityKit
import AppIntents
import Foundation

// Shared by the app (which starts and updates the Live Activities) and the widget extension (which draws them).

// MARK: Run

struct RunActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable { case locating, running, paused }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        var kind: RunSegment.Kind
        var round: Int
        /// Plan intervals fully covered so far.
        var completedSegments: Int
        /// How far through the current interval, in steps of 2% so small GPS updates do not redraw the lock screen.
        var progress: Double
        /// Hundredths of a mile left in this interval. During cool down, hundredths covered since the plan ended.
        var intervalHundredths: Int
        var totalHundredths: Int
        /// When the clock would have started had there been no pauses. Nil unless running.
        var timerStart: Date?
        /// Active seconds, frozen. Nil unless paused.
        var pausedSeconds: Int?
    }

    var plan: RunPlan
}

extension RunActivityAttributes.ContentState {
    static func make(engine: RunEngine, phase: RunActivityAttributes.Phase, timerStart: Date?, pausedSeconds: TimeInterval?) -> Self {
        Self(
            phase: phase,
            kind: engine.kind,
            round: engine.round,
            completedSegments: engine.completed.count,
            progress: (engine.progress * 50).rounded() / 50,
            intervalHundredths: Self.hundredths(engine.remaining ?? engine.segmentMeters),
            totalHundredths: Self.hundredths(engine.totalMeters),
            timerStart: phase == .running ? timerStart : nil,
            pausedSeconds: phase == .paused ? pausedSeconds.map { Int($0) } : nil
        )
    }

    static func hundredths(_ meters: Double) -> Int { Int((meters / RunPlan.metersPerMile * 100).rounded()) }

    var intervalMiles: String { String(format: "%.2f", Double(intervalHundredths) / 100) }
    var totalMiles: String { String(format: "%.2f", Double(totalHundredths) / 100) }
    var planComplete: Bool { kind == .cooldown }

    func roundLabel(plan: RunPlan) -> String {
        planComplete ? "Plan complete" : "Round \(round) of \(plan.rounds)"
    }

    /// What comes after the current interval, in the same words the in-app run screen uses.
    func nextUp(plan: RunPlan) -> String {
        switch (phase, kind) {
        case (.locating, _): return "First up: run \(RunFormat.planMiles(plan.runMiles)) mi"
        case (_, .cooldown): return "Walk it off, then finish"
        case (_, .run) where plan.walkMiles > 0: return "Next: walk \(RunFormat.planMiles(plan.walkMiles)) mi"
        case (_, _) where round >= plan.rounds: return "Last one, then cool down"
        default: return "Next: run \(RunFormat.planMiles(plan.runMiles)) mi"
        }
    }

    func rail(plan: RunPlan) -> [PlanRail.Segment] {
        PlanRail.segments(plan: plan, completed: completedSegments, progress: phase == .locating ? 0 : progress)
    }
}

/// The whole plan as one row of intervals, each as wide as its distance and filled as far as you have got.
enum PlanRail {
    struct Segment: Equatable {
        var kind: RunSegment.Kind
        /// Relative width (metres).
        var weight: Double
        /// 0 to 1.
        var fill: Double
    }

    static func segments(plan: RunPlan, completed: Int, progress: Double) -> [Segment] {
        var out: [Segment] = []
        for _ in 0..<max(plan.rounds, 1) {
            out.append(Segment(kind: .run, weight: max(plan.runMeters, 1), fill: 0))
            if plan.walkMeters > 0 { out.append(Segment(kind: .walk, weight: plan.walkMeters, fill: 0)) }
        }
        for i in out.indices {
            out[i].fill = i < completed ? 1 : (i == completed ? min(max(progress, 0), 1) : 0)
        }
        return out
    }
}

// MARK: Workout

struct WorkoutActivityAttributes: ActivityAttributes {
    enum Mark: Int, Codable, Hashable { case pending, done, record }

    struct ContentState: Codable, Hashable {
        /// The exercise with the next set to do. Empty when every set is done or nothing has been added.
        var exerciseName: String
        var exerciseNumber: Int
        var exerciseCount: Int
        var setNumber: Int
        var setCount: Int
        /// For example "190 lb x 8". Empty until weight or reps are filled in.
        var target: String
        /// For example "185 x 8".
        var last: String?
        /// One row of marks per exercise, one mark per set.
        var marks: [[Mark]]
        /// False until the next set has a weight or reps, because a set cannot be saved empty.
        var canComplete: Bool
        var setId: UUID?

        var totalSets: Int { marks.reduce(0) { $0 + $1.count } }
        var doneSets: Int { marks.reduce(0) { $0 + $1.filter { $0 != .pending }.count } }
        var records: Int { marks.reduce(0) { $0 + $1.filter { $0 == .record }.count } }
        var allDone: Bool { totalSets > 0 && doneSets == totalSets }
        var progress: Double { totalSets > 0 ? Double(doneSets) / Double(totalSets) : 0 }
    }

    var title: String
    var startedAt: Date
    var sessionId: String?
}

// MARK: Lock screen buttons

/// Lock screen buttons run in the app's process. The app fills these in at launch.
@MainActor
enum LiveActivityBridge {
    static var resumeRun: (() -> Void)?
    static var completeSet: ((String, UUID) async -> Void)?
}

struct ResumeRunIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume run"

    @MainActor
    func perform() async throws -> some IntentResult {
        LiveActivityBridge.resumeRun?()
        return .result()
    }
}

struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark set done"

    @Parameter(title: "Workout") var sessionId: String?
    @Parameter(title: "Set") var setId: String?

    init() {}

    init(sessionId: String, setId: UUID) {
        self.sessionId = sessionId
        self.setId = setId.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let sessionId, let setId, let id = UUID(uuidString: setId) {
            await LiveActivityBridge.completeSet?(sessionId, id)
        }
        return .result()
    }
}
