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

        // The finished workout shows up in history with the sets that were checked off. Other tests share the demo data, so find it by ID.
        #expect(store.savedNotice?.contains("3 sets") == true)
        let latest = try #require(store.history.first { $0.id == resumed.id })
        #expect(latest.exercises.first?.exerciseId == legPress.id)
        #expect(latest.exercises.count == 2)
        #expect(latest.setCount == 3)
        #expect(latest.duration != nil)
        #expect(store.historySince == TrainStore.monthStart(Date()))

        // Leg press beats the earlier demo sessions' best, so the day view shows it against last time.
        let progress = await store.progress(for: latest)
        let legProgress = try #require(progress[legPress.id])
        #expect(legProgress.top?.weight == 190)
        #expect(legProgress.previous != nil)

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

        // Removing an exercise added by mistake deletes its saved sets, so it does not come back when the workout resumes.
        let sessionId = try #require(store.session?.id)
        await store.removeExercise(blank.id)
        #expect(store.errorMessage == nil)
        #expect(!store.blocks.contains { $0.id == blank.id })
        let leftover: [WorkoutSet] = try await API.get("workout_sets", query: ["session_id": "eq.\(sessionId)", "exercise_id": "eq.\(blank.id)"])
        #expect(leftover.isEmpty)
        let reopened = TrainStore()
        await reopened.load()
        #expect(reopened.session?.id == sessionId)
        #expect(!reopened.blocks.contains { $0.id == blank.id })
    }

    @Test func progressComparesWithThePreviousSession() throws {
        func set(_ id: String, _ session: String, _ weight: Double, _ reps: Int, _ at: String) -> WorkoutSet {
            WorkoutSet(id: id, sessionId: session, exerciseId: "bench", setNo: 1, weight: weight, reps: reps, done: true, createdAt: at)
        }
        let today = [set("t1", "now", 135, 10, "2026-11-17T22:20:00Z"), set("t2", "now", 155, 8, "2026-11-17T22:25:00Z")]
        let older = [set("o1", "old", 160, 8, "2026-11-01T22:00:00Z")]
        let last = [set("l1", "last", 145, 8, "2026-11-10T22:00:00Z")]
        let later = [set("n1", "next", 300, 8, "2026-11-20T22:00:00Z")]
        let history = (later + today + last + older).sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }

        let p = TrainStore.progress(today, history: history, sessionId: "now", before: "2026-11-17T22:20:00Z")
        #expect(p.top?.id == "t2")
        #expect(p.previous?.id == "l1")
        // 155 x 8 beats last week but not the 160 x 8 before that, and the later session does not count.
        #expect(!p.isPR)
        let change = WorkoutFormat.change(try #require(p.top), vs: try #require(p.previous), unit: "lb")
        #expect(change.text == "+10 lb vs last time")
        #expect(change.up == true)
    }
}
