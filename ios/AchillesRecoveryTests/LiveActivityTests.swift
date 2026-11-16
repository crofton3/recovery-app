import Foundation
import Testing
@testable import AchillesRecovery

struct PlanRailTests {
    private let plan = RunPlan(runMiles: 0.3, walkMiles: 0.1, rounds: 4)

    @Test func oneSegmentPerIntervalSizedByDistance() {
        let rail = PlanRail.segments(plan: plan, completed: 0, progress: 0)
        #expect(rail.map(\.kind) == [.run, .walk, .run, .walk, .run, .walk, .run, .walk])
        #expect(abs(rail[0].weight / rail[1].weight - 3) < 0.0001)
        #expect(rail.allSatisfy { $0.fill == 0 })
    }

    @Test func fillsDoneIntervalsAndPartOfTheCurrentOne() {
        let rail = PlanRail.segments(plan: plan, completed: 2, progress: 0.6)
        #expect(rail.map(\.fill) == [1, 1, 0.6, 0, 0, 0, 0, 0])
    }

    @Test func everythingIsFullOnceThePlanIsDone() {
        let rail = PlanRail.segments(plan: plan, completed: 8, progress: 1)
        #expect(rail.allSatisfy { $0.fill == 1 })
    }

    @Test func noWalkBreaksMeansRunSegmentsOnly() {
        let rail = PlanRail.segments(plan: RunPlan(runMiles: 0.5, walkMiles: 0, rounds: 3), completed: 1, progress: 2)
        #expect(rail.map(\.kind) == [.run, .run, .run])
        #expect(rail.map(\.fill) == [1, 1, 0])
    }
}

struct RunActivityStateTests {
    private let mile = RunPlan.metersPerMile
    private let plan = RunPlan(runMiles: 0.3, walkMiles: 0.1, rounds: 4)
    private typealias State = RunActivityAttributes.ContentState

    /// Round 1 done, 0.18 mi into the second run: the state drawn in the design.
    private func midRun() -> RunEngine {
        var engine = RunEngine(plan: plan)
        _ = engine.advance(meters: 0.58 * mile, elapsed: 432)
        return engine
    }

    @Test func runningShowsMilesLeftTotalAndALiveClock() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let state = State.make(engine: midRun(), phase: .running, timerStart: start, pausedSeconds: 432)
        #expect(state.kind == .run)
        #expect(state.round == 2)
        #expect(state.completedSegments == 2)
        #expect(state.intervalMiles == "0.12")
        #expect(state.totalMiles == "0.58")
        #expect(abs(state.progress - 0.6) < 0.0001)
        #expect(state.timerStart == start)
        #expect(state.pausedSeconds == nil)
        #expect(state.roundLabel(plan: plan) == "Round 2 of 4")
        #expect(state.nextUp(plan: plan) == "Next: walk 0.1 mi")
        #expect(state.rail(plan: plan).map(\.fill) == [1, 1, 0.6, 0, 0, 0, 0, 0])
    }

    @Test func pausedFreezesTheClock() {
        let state = State.make(engine: midRun(), phase: .paused, timerStart: nil, pausedSeconds: 432.7)
        #expect(state.timerStart == nil)
        #expect(state.pausedSeconds == 432)
    }

    @Test func smallMovesDoNotChangeTheState() {
        var engine = midRun()
        let before = State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil)
        _ = engine.advance(meters: 3, elapsed: 434)
        #expect(State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil) == before)
        _ = engine.advance(meters: 30, elapsed: 440)
        #expect(State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil) != before)
    }

    @Test func findingGPSShowsAnEmptyRail() {
        let state = State.make(engine: RunEngine(plan: plan), phase: .locating, timerStart: nil, pausedSeconds: nil)
        #expect(state.nextUp(plan: plan) == "First up: run 0.3 mi")
        #expect(state.rail(plan: plan).allSatisfy { $0.fill == 0 })
    }

    @Test func lastWalkThenCoolDown() {
        var engine = RunEngine(plan: plan)
        _ = engine.advance(meters: 1.54 * mile, elapsed: 1132)
        let lastWalk = State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil)
        #expect(lastWalk.kind == .walk)
        #expect(lastWalk.intervalMiles == "0.06")
        #expect(lastWalk.nextUp(plan: plan) == "Last one, then cool down")

        _ = engine.advance(meters: 0.2 * mile, elapsed: 1300)
        let cool = State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil)
        #expect(cool.planComplete)
        #expect(cool.intervalMiles == "0.14")
        #expect(cool.totalMiles == "1.74")
        #expect(cool.roundLabel(plan: plan) == "Plan complete")
        #expect(cool.nextUp(plan: plan) == "Walk it off, then finish")
        #expect(cool.rail(plan: plan).allSatisfy { $0.fill == 1 })
    }

    @Test func noWalkPlanPointsAtTheNextRun() {
        let plan = RunPlan(runMiles: 0.5, walkMiles: 0, rounds: 2)
        var engine = RunEngine(plan: plan)
        _ = engine.advance(meters: 0.1 * mile, elapsed: 60)
        #expect(State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil).nextUp(plan: plan) == "Next: run 0.5 mi")
        _ = engine.advance(meters: 0.5 * mile, elapsed: 360)
        #expect(State.make(engine: engine, phase: .running, timerStart: nil, pausedSeconds: nil).nextUp(plan: plan) == "Last one, then cool down")
    }
}

@MainActor
struct WorkoutActivityStateTests {
    private typealias State = WorkoutActivityAttributes.ContentState
    private typealias Draft = TrainStore.SetDraft

    private func block(_ name: String, unit: String = "lb", _ sets: [Draft]) -> TrainStore.ExerciseBlock {
        TrainStore.ExerciseBlock(exercise: Exercise(id: name, name: name, category: "strength", unit: unit), sets: sets, priorBest: 0)
    }

    @Test func pointsAtTheFirstSetNotDone() {
        let blocks = [
            block("Squat", [Draft(weight: "135", reps: "8", done: true), Draft(weight: "135", reps: "8", done: true, isPR: true)]),
            block("Leg press", [
                Draft(weight: "190", reps: "8", done: true),
                Draft(weight: "190", reps: "8", done: false, lastWeight: 185, lastReps: 8),
                Draft(weight: "190", reps: "8", done: false),
            ]),
            block("Seated calf raise", [Draft(weight: "", reps: "", done: false)]),
        ]
        let state = State.make(blocks: blocks)
        #expect(state.exerciseName == "Leg press")
        #expect(state.exerciseNumber == 2)
        #expect(state.exerciseCount == 3)
        #expect(state.setNumber == 2)
        #expect(state.setCount == 3)
        #expect(state.target == "190 lb x 8")
        #expect(state.last == "185 x 8")
        #expect(state.canComplete)
        #expect(state.marks == [[.done, .record], [.done, .pending, .pending], [.pending]])
        #expect(state.doneSets == 3)
        #expect(state.totalSets == 6)
        #expect(state.records == 1)
        #expect(!state.allDone)
    }

    @Test func anEmptySetCannotBeCompletedFromTheLockScreen() {
        let state = State.make(blocks: [block("Plank", unit: "reps", [Draft(weight: "", reps: "", done: false)])])
        #expect(state.target.isEmpty)
        #expect(state.last == nil)
        #expect(!state.canComplete)
    }

    @Test func describesWeightAndRepsHoweverMuchIsFilledIn() {
        #expect(State.describe(weight: "190", reps: "8", unit: "lb", withUnit: true) == "190 lb x 8")
        #expect(State.describe(weight: "190", reps: "", unit: "lb", withUnit: true) == "190 lb")
        #expect(State.describe(weight: "", reps: "12", unit: "reps", withUnit: true) == "12 reps")
        #expect(State.describe(weight: "185", reps: "8", unit: "lb", withUnit: false) == "185 x 8")
        #expect(State.describe(weight: "", reps: "", unit: "lb", withUnit: true).isEmpty)
    }

    @Test func allDoneAndEmptySessions() {
        let done = State.make(blocks: [block("Squat", [Draft(weight: "135", reps: "8", done: true)])])
        #expect(done.allDone)
        #expect(done.exerciseName.isEmpty)
        #expect(!done.canComplete)

        let empty = State.make(blocks: [])
        #expect(!empty.allDone)
        #expect(empty.totalSets == 0)
        #expect(empty.progress == 0)
    }
}

extension TrainStoreTests {
    /// The lock screen check button: marks the next set done and tells the Live Activity.
    @Test func completeNextSetMarksTheSetOnTheLockScreen() async throws {
        defer { UserDefaults.standard.removeObject(forKey: "demoMode") }
        let store = TrainStore()
        var states: [WorkoutActivityAttributes.ContentState] = []
        store.onLiveChange = { states.append(.make(blocks: $0.blocks)) }

        await store.load()
        if store.session == nil { await store.startSession(from: nil) }
        if !store.blocks.contains(where: { $0.sets.contains { !$0.done } }) {
            let unused = try #require(store.exercises.first { ex in !store.blocks.contains { $0.id == ex.id } })
            await store.addExercise(unused)
        }
        let block = try #require(store.blocks.first { $0.sets.contains { !$0.done } })
        let set = try #require(block.sets.first { !$0.done })
        store.binding(exerciseId: block.id, setId: set.id, fallback: set).wrappedValue.reps = "8"
        let before = try #require(states.last)
        #expect(before.exerciseName == block.exercise.name)
        #expect(before.canComplete)

        await store.completeNextSet()
        #expect(store.errorMessage == nil)
        #expect(store.blocks.first { $0.id == block.id }?.sets.first { $0.id == set.id }?.done == true)
        #expect(states.last?.doneSets == before.doneSets + 1)

        // The demo data is shared with the other tests in this suite, so put the set back.
        await store.toggleDone(exerciseId: block.id, setId: set.id)
        #expect(states.last?.doneSets == before.doneSets)
    }
}
