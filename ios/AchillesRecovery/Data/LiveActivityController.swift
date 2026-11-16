import ActivityKit
import Foundation

/// Starts, updates and ends the lock screen Live Activities for a run and for a lifting session.
/// Everything is local: no push tokens and no server.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var run: Activity<RunActivityAttributes>?
    private var lastRun: RunActivityAttributes.ContentState?
    private var workout: Activity<WorkoutActivityAttributes>?
    private var lastWorkout: WorkoutActivityAttributes.ContentState?
    /// Updates are sent one after another so an older state can never land on top of a newer one.
    private var queue: Task<Void, Never>?

    private init() {}

    // MARK: Run

    /// Pass nil when no run is in progress.
    func syncRun(plan: RunPlan, state: RunActivityAttributes.ContentState?) {
        guard let state else {
            end(run)
            run = nil
            lastRun = nil
            return
        }
        guard state != lastRun else { return }
        lastRun = state
        if let run {
            enqueue { await run.update(ActivityContent(state: state, staleDate: nil)) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            run = try? Activity.request(attributes: RunActivityAttributes(plan: plan), content: ActivityContent(state: state, staleDate: nil))
        }
    }

    /// A run cannot survive the app being closed, so anything still on the lock screen at launch is left over.
    func endLeftoverRuns() {
        for activity in Activity<RunActivityAttributes>.activities { end(activity) }
    }

    // MARK: Workout

    /// Pass a nil session when no workout is in progress.
    func syncWorkout(session: WorkoutSession?, blocks: [TrainStore.ExerciseBlock]) {
        guard let session else {
            for activity in Activity<WorkoutActivityAttributes>.activities { end(activity) }
            workout = nil
            lastWorkout = nil
            return
        }
        let state = WorkoutActivityAttributes.ContentState.make(blocks: blocks)
        guard state != lastWorkout else { return }
        lastWorkout = state
        // After a relaunch, pick the workout's activity back up instead of starting a second one.
        if workout == nil { workout = Activity<WorkoutActivityAttributes>.activities.first { $0.attributes.title == session.title } }
        if let workout {
            enqueue { await workout.update(ActivityContent(state: state, staleDate: nil)) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            let started = session.startedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            let attributes = WorkoutActivityAttributes(title: session.title, startedAt: started)
            workout = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        }
    }

    // MARK: Plumbing

    private func end<A: ActivityAttributes>(_ activity: Activity<A>?) {
        guard let activity else { return }
        enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await work()
        }
    }
}

extension WorkoutActivityAttributes.ContentState {
    /// What the lock screen shows for a workout: the first set not yet done, and a mark for every set.
    @MainActor
    static func make(blocks: [TrainStore.ExerciseBlock]) -> Self {
        let marks = blocks.map { block in
            block.sets.map { set -> WorkoutActivityAttributes.Mark in set.done ? (set.isPR ? .record : .done) : .pending }
        }
        guard let bi = blocks.firstIndex(where: { $0.sets.contains { !$0.done } }),
              let si = blocks[bi].sets.firstIndex(where: { !$0.done }) else {
            return Self(exerciseName: "", exerciseNumber: blocks.count, exerciseCount: blocks.count, setNumber: 0, setCount: 0,
                        target: "", last: nil, marks: marks, canComplete: false)
        }
        let block = blocks[bi]
        let set = block.sets[si]
        let unit = block.exercise.unit
        return Self(
            exerciseName: block.exercise.name,
            exerciseNumber: bi + 1,
            exerciseCount: blocks.count,
            setNumber: si + 1,
            setCount: block.sets.count,
            target: describe(weight: set.weight, reps: set.reps, unit: unit, withUnit: true),
            last: set.lastWeight == nil && set.lastReps == nil ? nil
                : describe(weight: TrainStore.format(set.lastWeight), reps: set.lastReps.map(String.init) ?? "", unit: unit, withUnit: false),
            marks: marks,
            canComplete: Double(set.weight) != nil || Int(set.reps) != nil
        )
    }

    /// "190 lb x 8", "190 lb", "8 reps" or "". Without the unit: "185 x 8".
    static func describe(weight: String, reps: String, unit: String, withUnit: Bool) -> String {
        if weight.isEmpty { return reps.isEmpty ? "" : "\(reps) reps" }
        if reps.isEmpty { return "\(weight) \(unit)" }
        return withUnit ? "\(weight) \(unit) x \(reps)" : "\(weight) x \(reps)"
    }
}
