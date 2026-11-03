import Foundation
import Observation

@MainActor
@Observable
final class TrainStore {
    struct SetDraft: Identifiable {
        let id = UUID()
        var serverId: String?
        var weight: String
        var reps: String
        var done: Bool
        var lastWeight: Double?
        var lastReps: Int?
        var isPR = false
    }

    struct ExerciseBlock: Identifiable {
        var id: String { exercise.id }
        var exercise: Exercise
        var sets: [SetDraft]
        /// Best score from earlier sessions. Zero means no history, so nothing is flagged as a PR.
        var priorBest: Double
    }

    var exercises: [Exercise] = []
    var weekSchedule: [ScheduleItem] = []
    var session: WorkoutSession?
    var blocks: [ExerciseBlock] = []
    var errorMessage: String?

    // MARK: Loading

    func load() async {
        do { exercises = try await API.get("exercises", query: ["order": "name"]) } catch { errorMessage = error.localizedDescription }
        do { weekSchedule = try await API.get("schedule_items", query: ["order": "weekday,reminder_time"]) } catch { errorMessage = error.localizedDescription }
        await resume()
    }

    /// Picks up an unfinished session from today (for example after relaunching the app).
    private func resume() async {
        guard session == nil else { return }
        let open: [WorkoutSession] = (try? await API.get("workout_sessions", query: ["date": "eq.\(Day.string())", "completed_at": "is.null", "order": "started_at.desc", "limit": "1"])) ?? []
        guard let s = open.first else { return }
        session = s
        let sets: [WorkoutSet] = (try? await API.get("workout_sets", query: ["session_id": "eq.\(s.id)", "order": "created_at"])) ?? []
        var order: [String] = []
        for set in sets where !order.contains(set.exerciseId) { order.append(set.exerciseId) }
        var rebuilt: [ExerciseBlock] = []
        for exId in order {
            guard let ex = exercises.first(where: { $0.id == exId }) else { continue }
            rebuilt.append(await buildBlock(ex, existing: sets.filter { $0.exerciseId == exId }))
        }
        blocks = rebuilt
    }

    // MARK: Session

    func startSession(from item: ScheduleItem?) async {
        do {
            let new = NewSession(date: Day.string(), title: item?.title ?? "Workout", scheduleItemId: item?.id, startedAt: ISO8601DateFormatter().string(from: Date()))
            session = try await API.insert("workout_sessions", new, as: WorkoutSession.self)
            blocks = []
            for id in item?.exerciseIds ?? [] {
                if let ex = exercises.first(where: { $0.id == id }) { blocks.append(await buildBlock(ex, existing: [])) }
            }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func addExercise(_ ex: Exercise) async {
        guard !blocks.contains(where: { $0.id == ex.id }) else { return }
        blocks.append(await buildBlock(ex, existing: []))
    }

    func finish() async {
        guard let session else { return }
        do {
            try await API.patch("workout_sessions", id: session.id, SessionComplete(completedAt: ISO8601DateFormatter().string(from: Date())))
            self.session = nil
            blocks = []
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func addSet(to exerciseId: String) {
        guard let bi = blocks.firstIndex(where: { $0.id == exerciseId }) else { return }
        let last = blocks[bi].sets.last
        blocks[bi].sets.append(SetDraft(weight: last?.weight ?? "", reps: last?.reps ?? "", done: false))
    }

    func toggleDone(exerciseId: String, setId: UUID) async {
        guard let session,
              let bi = blocks.firstIndex(where: { $0.id == exerciseId }),
              let si = blocks[bi].sets.firstIndex(where: { $0.id == setId }) else { return }
        let before = blocks[bi].sets[si]
        var s = before
        let weight = Double(s.weight)
        let reps = Int(s.reps)
        let newDone = !s.done
        if newDone && weight == nil && reps == nil {
            errorMessage = "Enter weight or reps first."
            return
        }
        s.done = newDone
        if newDone {
            let sc = Self.score(weight: weight, reps: reps)
            let otherBest = blocks[bi].sets.filter { $0.done && $0.id != setId }.map { Self.score(weight: Double($0.weight), reps: Int($0.reps)) }.max() ?? 0
            s.isPR = blocks[bi].priorBest > 0 && sc > blocks[bi].priorBest && sc >= otherBest
        } else {
            s.isPR = false
        }
        blocks[bi].sets[si] = s  // optimistic

        do {
            if let sid = s.serverId {
                try await API.patch("workout_sets", id: sid, SetUpdate(weight: weight, reps: reps, done: newDone))
            } else {
                let row: WorkoutSet = try await API.insert("workout_sets", NewSet(sessionId: session.id, exerciseId: exerciseId, setNo: si + 1, weight: weight, reps: reps, done: newDone), as: WorkoutSet.self)
                if let bi2 = blocks.firstIndex(where: { $0.id == exerciseId }), let si2 = blocks[bi2].sets.firstIndex(where: { $0.id == setId }) {
                    blocks[bi2].sets[si2].serverId = row.id
                }
            }
            errorMessage = nil
        } catch {
            if let bi2 = blocks.firstIndex(where: { $0.id == exerciseId }), let si2 = blocks[bi2].sets.firstIndex(where: { $0.id == setId }) {
                blocks[bi2].sets[si2] = before
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: History

    /// Epley estimated one-rep max for weighted sets, reps for bodyweight sets.
    static func score(weight: Double?, reps: Int?) -> Double {
        let r = Double(reps ?? 0)
        if let w = weight, w > 0 { return w * (1 + r / 30) }
        return r
    }

    static func format(_ value: Double?) -> String {
        guard let v = value else { return "" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }

    private func buildBlock(_ ex: Exercise, existing: [WorkoutSet]) async -> ExerciseBlock {
        let history: [WorkoutSet] = (try? await API.get("workout_sets", query: ["exercise_id": "eq.\(ex.id)", "done": "eq.true", "order": "created_at.desc", "limit": "300"])) ?? []
        let prior = history.filter { $0.sessionId != session?.id }
        let best = prior.map { Self.score(weight: $0.weight, reps: $0.reps) }.max() ?? 0
        let lastSessionId = prior.first?.sessionId
        let last = prior.filter { $0.sessionId == lastSessionId }.sorted { $0.setNo < $1.setNo }

        var drafts: [SetDraft] = []
        if !existing.isEmpty {
            for (i, s) in existing.sorted(by: { $0.setNo < $1.setNo }).enumerated() {
                let l = last.indices.contains(i) ? last[i] : nil
                drafts.append(SetDraft(serverId: s.id, weight: Self.format(s.weight), reps: s.reps.map(String.init) ?? "", done: s.done, lastWeight: l?.weight, lastReps: l?.reps))
            }
        } else {
            for i in 0..<max(last.count, 3) {
                let exact = last.indices.contains(i) ? last[i] : nil
                let source = exact ?? last.last
                drafts.append(SetDraft(weight: Self.format(source?.weight), reps: source?.reps.map(String.init) ?? "", done: false, lastWeight: exact?.weight, lastReps: exact?.reps))
            }
        }
        return ExerciseBlock(exercise: ex, sets: drafts, priorBest: best)
    }

    // MARK: Library and schedule

    func createExercise(name: String, category: String, unit: String) async -> Exercise? {
        do {
            let ex: Exercise = try await API.insert("exercises", NewExercise(name: name, category: category, unit: unit), as: Exercise.self)
            exercises.append(ex)
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            errorMessage = nil
            return ex
        } catch { errorMessage = error.localizedDescription; return nil }
    }

    func saveScheduleItem(id: String?, weekday: Int, title: String, exerciseIds: [String], reminderTime: String?) async {
        let body = ScheduleWrite(weekday: weekday, title: title, exerciseIds: exerciseIds, reminderTime: reminderTime)
        do {
            if let id { try await API.patch("schedule_items", id: id, body) }
            else { _ = try await API.insert("schedule_items", body, as: ScheduleItem.self) }
            weekSchedule = try await API.get("schedule_items", query: ["order": "weekday,reminder_time"])
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteScheduleItem(_ id: String) async {
        do {
            try await API.delete("schedule_items", id: id)
            weekSchedule.removeAll { $0.id == id }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
