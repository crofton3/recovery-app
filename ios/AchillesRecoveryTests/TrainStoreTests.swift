import Foundation
import Testing
@testable import AchillesRecovery

/// Runs the real TrainStore against demo data. The demo seed has today's lower-body workout already in progress.
@MainActor
@Suite(.serialized)
struct TrainStoreTests {
    init() { UserDefaults.standard.set(true, forKey: "demoMode") }

    @Test func workoutLifecycle() async throws {
        defer { UserDefaults.standard.removeObject(forKey: "demoMode") }
        let store = TrainStore()

        // Load picks up the unfinished session from today.
        await store.load()
        #expect(store.errorMessage == nil)
        #expect(store.exercises.count >= 8)
        #expect(store.exercises.map(\.name) == store.exercises.map(\.name).sorted())
        let resumed = try #require(store.session)
        #expect(resumed.completedAt == nil)
        #expect(store.blocks.map(\.exercise.name) == ["Leg press", "Seated calf raise"])
        let legPress = try #require(store.blocks.first)
        #expect(legPress.sets.map(\.done) == [true, true, false])
        #expect(legPress.priorBest > 0)

        // Finishing clears the screen state. Rows still on screen read through the binding, which must not crash.
        let staleSet = legPress.sets[0]
        let binding = store.binding(exerciseId: legPress.id, setId: staleSet.id, fallback: staleSet)
        await store.finish()
        #expect(store.session == nil)
        #expect(store.blocks.isEmpty)
        #expect(binding.wrappedValue.id == staleSet.id)
        binding.wrappedValue.weight = "999"
        let open: [WorkoutSession] = try await API.get("workout_sessions", query: ["date": "eq.\(Day.string())", "completed_at": "is.null"])
        #expect(open.isEmpty)

        // Starting from today's scheduled item builds every planned exercise with the planned sets and reps.
        let today = try #require(store.weekSchedule.first { $0.weekday == Day.weekday && !($0.plan ?? []).isEmpty })
        await store.startSession(from: today)
        #expect(store.session?.scheduleItemId == today.id)
        #expect(store.blocks.count == today.entries.count)
        let first = try #require(store.blocks.first)
        let plan = try #require(first.plan)
        #expect(first.sets.count == plan.sets)
        #expect(first.sets.allSatisfy { $0.reps == String(plan.reps) && !$0.done })

        // A set needs a weight or reps before it can be marked done.
        let blank = try #require(store.blocks.first(where: { $0.exercise.name == "Leg press" }))
        store.blocks[0].sets[0].weight = ""
        store.blocks[0].sets[0].reps = ""
        await store.toggleDone(exerciseId: store.blocks[0].id, setId: store.blocks[0].sets[0].id)
        #expect(store.errorMessage == "Enter weight or reps first.")
        #expect(store.blocks[0].sets[0].done == false)

        // Beating every earlier session flags a PR and saves the set.
        let bi = try #require(store.blocks.firstIndex { $0.id == blank.id })
        store.blocks[bi].sets[0].weight = "500"
        store.blocks[bi].sets[0].reps = "10"
        await store.toggleDone(exerciseId: blank.id, setId: store.blocks[bi].sets[0].id)
        #expect(store.errorMessage == nil)
        #expect(store.blocks[bi].sets[0].done)
        #expect(store.blocks[bi].sets[0].isPR)
        let savedId = try #require(store.blocks[bi].sets[0].serverId)
        let saved: [WorkoutSet] = try await API.get("workout_sets", query: ["id": "eq.\(savedId)"])
        #expect(saved.first?.weight == 500)

        // A lighter set afterwards is not a PR.
        store.blocks[bi].sets[1].weight = "100"
        store.blocks[bi].sets[1].reps = "5"
        await store.toggleDone(exerciseId: blank.id, setId: store.blocks[bi].sets[1].id)
        #expect(store.blocks[bi].sets[1].done)
        #expect(!store.blocks[bi].sets[1].isPR)
    }
}
