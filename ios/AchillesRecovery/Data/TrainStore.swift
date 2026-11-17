import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class TrainStore {
    struct SetDraft: Codable, Identifiable {
        var id = UUID()
        var serverId: String?
        var weight: String
        var reps: String
        var done: Bool
        var lastWeight: Double?
        var lastReps: Int?
        var isPR = false
    }

    struct ExerciseBlock: Codable, Identifiable {
        var id: String { exercise.id }
        var exercise: Exercise
        var sets: [SetDraft]
        /// Best score from earlier sessions. Zero means no history, so nothing is flagged as a PR.
        var priorBest: Double
        var plan: PlanEntry?
    }

    private struct SavedWorkout: Codable {
        var sessionId: String
        var blocks: [ExerciseBlock]
    }

    var exercises: [Exercise] = []
    var weekSchedule: [ScheduleItem] = []
    var session: WorkoutSession?
    var blocks: [ExerciseBlock] = []
    var errorMessage: String?
    /// Called whenever the workout on the lock screen may have changed. The app points this at the Live Activity.
    @ObservationIgnored var onLiveChange: ((TrainStore) -> Void)?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var starting = false
    @ObservationIgnored private var finishing = false
    @ObservationIgnored private var savingSets: Set<UUID> = []
    private let draftURL: URL?

    init(draftURL: URL? = nil) {
        self.draftURL = draftURL ?? (DemoMode.isOn ? nil : URL.applicationSupportDirectory.appending(path: "workout-drafts.json"))
    }

    // MARK: Loading

    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await loadWorkout() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func loadWorkout() async {
        do { exercises = try await API.get("exercises", query: ["order": "name"]) } catch { errorMessage = error.localizedDescription }
        do { weekSchedule = try await API.get("schedule_items", query: ["order": "weekday,reminder_time"]) } catch { errorMessage = error.localizedDescription }
        guard !starting, !finishing else { return }
        do {
            if session == nil { try await resume() }
            publishWorkout()
        } catch { errorMessage = error.localizedDescription }
    }

    /// Restores local drafts and reconciles sets that the server saved before the app exited.
    private func resume() async throws {
        let saved = try readDrafts()
        var open: [WorkoutSession] = []
        if let saved {
            open = try await API.get("workout_sessions", query: ["id": "eq.\(saved.sessionId)", "completed_at": "is.null"])
        }
        if open.isEmpty {
            open = try await API.get("workout_sessions", query: [
                "date": "eq.\(Day.string())", "completed_at": "is.null", "order": "started_at.desc", "limit": "1",
            ])
        }
        guard let active = open.first else { return }
        let rows: [WorkoutSet] = try await API.get("workout_sets", query: ["session_id": "eq.\(active.id)", "order": "created_at"])
        var restored = saved.flatMap { $0.sessionId == active.id ? $0.blocks : nil } ?? []
        for index in restored.indices {
            let exerciseRows = rows.filter { $0.exerciseId == restored[index].id }
            restored[index].sets = Self.restoreSets(in: restored[index], from: exerciseRows)
        }
        for row in rows where !restored.contains(where: { $0.id == row.exerciseId }) {
            guard let exercise = exercises.first(where: { $0.id == row.exerciseId }) else { continue }
            restored.append(await buildBlock(exercise, sessionId: active.id, existing: rows.filter { $0.exerciseId == exercise.id }))
        }
        session = active
        blocks = restored
    }

    private static func restoreSets(in block: ExerciseBlock, from rows: [WorkoutSet]) -> [SetDraft] {
        var remaining = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        var drafts = block.sets.map { draft in
            guard let row = remaining.removeValue(forKey: draft.serverId ?? draft.id.uuidString.lowercased()) else { return draft }
            var restored = draft
            restored.serverId = row.id
            if row.done != draft.done {
                restored.done = row.done
                restored.weight = Self.format(row.weight)
                restored.reps = row.reps.map(String.init) ?? ""
            }
            return restored
        }
        drafts += remaining.values.sorted { $0.setNo < $1.setNo }.map { draft(from: $0) }
        restoreRecords(in: &drafts, priorBest: block.priorBest)
        return drafts
    }

    private func readDrafts() throws -> SavedWorkout? {
        guard let draftURL else { return nil }
        do { return try JSONDecoder().decode(SavedWorkout.self, from: Data(contentsOf: draftURL)) }
        catch CocoaError.fileReadNoSuchFile { return nil }
    }

    /// Persist the button's target before exposing it to ActivityKit.
    private func publishWorkout() {
        do {
            if let draftURL {
                if let session {
                    try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let saved = try JSONEncoder().encode(SavedWorkout(sessionId: session.id, blocks: blocks))
                    try saved.write(to: draftURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                } else if FileManager.default.fileExists(atPath: draftURL.path) {
                    try FileManager.default.removeItem(at: draftURL)
                }
            }
            onLiveChange?(self)
        } catch {
            errorMessage = error.localizedDescription
            if session == nil { onLiveChange?(self) }
        }
    }

    /// A binding that survives the block being removed (finishing a workout clears blocks while rows are still on screen).
    func binding(exerciseId: String, setId: UUID, fallback: SetDraft) -> Binding<SetDraft> {
        Binding(
            get: { [self] in blocks.first { $0.id == exerciseId }?.sets.first { $0.id == setId } ?? fallback },
            set: { [self] new in
                if !savingSets.contains(setId),
                   let bi = blocks.firstIndex(where: { $0.id == exerciseId }), let si = blocks[bi].sets.firstIndex(where: { $0.id == setId }) {
                    blocks[bi].sets[si] = new
                    publishWorkout()
                }
            }
        )
    }

    // MARK: Session

    func startSession(from item: ScheduleItem?) async {
        await loadTask?.value
        guard session == nil, !starting else { return }
        starting = true
        defer { starting = false }
        do {
            let new = NewSession(date: Day.string(), title: item?.title ?? "Workout", scheduleItemId: item?.id, startedAt: ISO8601DateFormatter().string(from: Date()))
            let active = try await API.insert("workout_sessions", new, as: WorkoutSession.self)
            var planned: [ExerciseBlock] = []
            for entry in item?.entries ?? [] {
                if let ex = exercises.first(where: { $0.id == entry.exerciseId }) {
                    planned.append(await buildBlock(ex, sessionId: active.id, existing: [], plan: entry.plan))
                }
            }
            session = active
            blocks = planned
            errorMessage = nil
            publishWorkout()
        } catch { errorMessage = error.localizedDescription }
    }

    func addExercise(_ ex: Exercise) async {
        guard let session, !finishing, !blocks.contains(where: { $0.id == ex.id }) else { return }
        let block = await buildBlock(ex, sessionId: session.id, existing: [])
        guard self.session?.id == session.id, !finishing, !blocks.contains(where: { $0.id == ex.id }) else { return }
        blocks.append(block)
        publishWorkout()
    }

    /// Takes an exercise out of the current workout, deleting any sets already saved for it so it doesn't come back on resume.
    func removeExercise(_ exerciseId: String) async {
        guard let session, !finishing,
              let block = blocks.first(where: { $0.id == exerciseId }),
              !block.sets.contains(where: { savingSets.contains($0.id) }) else { return }
        do {
            try await API.send("DELETE", "workout_sets", query: ["session_id": "eq.\(session.id)", "exercise_id": "eq.\(exerciseId)"], prefer: "return=minimal")
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard self.session?.id == session.id else { return }
        blocks.removeAll { $0.id == exerciseId }
        errorMessage = nil
        publishWorkout()
    }

    func finish() async {
        guard let session, !finishing, savingSets.isEmpty else { return }
        finishing = true
        defer { finishing = false }
        do {
            try await API.patch("workout_sessions", id: session.id, SessionComplete(completedAt: ISO8601DateFormatter().string(from: Date())))
            self.session = nil
            blocks = []
            errorMessage = nil
            publishWorkout()
            Task { await NotificationPlanner.refresh() }
        } catch { errorMessage = error.localizedDescription }
    }

    func addSet(to exerciseId: String) {
        guard let bi = blocks.firstIndex(where: { $0.id == exerciseId }) else { return }
        let last = blocks[bi].sets.last
        blocks[bi].sets.append(SetDraft(weight: last?.weight ?? "", reps: last?.reps ?? "", done: false))
        publishWorkout()
    }

    func toggleDone(exerciseId: String, setId: UUID) async {
        guard let session, !finishing, !savingSets.contains(setId),
              let bi = blocks.firstIndex(where: { $0.id == exerciseId }),
              let si = blocks[bi].sets.firstIndex(where: { $0.id == setId }) else { return }
        var s = blocks[bi].sets[si]
        let weight = Double(s.weight)
        let reps = Int(s.reps)
        let newDone = !s.done
        if newDone && weight == nil && reps == nil {
            errorMessage = "Enter weight or reps first."
            return
        }
        savingSets.insert(setId)
        defer { savingSets.remove(setId) }
        do {
            if let sid = s.serverId {
                try await API.patch("workout_sets", id: sid, SetUpdate(weight: weight, reps: reps, done: newDone))
            } else {
                // Use the draft ID as the row ID so even a retry after a lost response writes the same set.
                let sid = setId.uuidString.lowercased()
                let row = NewSet(id: sid, sessionId: session.id, exerciseId: exerciseId, setNo: si + 1, weight: weight, reps: reps, done: newDone)
                try await API.upsert("workout_sets", row, onConflict: "id")
                s.serverId = sid
            }
        } catch {
            errorMessage = error.localizedDescription
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
        blocks[bi].sets[si] = s
        errorMessage = nil
        publishWorkout()
    }

    /// Marks the set shown when the Live Activity button was rendered.
    func completeSet(sessionId: String, setId: UUID) async {
        if session == nil { await load() }
        guard session?.id == sessionId, let block = blocks.first(where: { $0.sets.contains { $0.id == setId && !$0.done } }) else { return }
        await toggleDone(exerciseId: block.id, setId: setId)
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

    private func buildBlock(_ ex: Exercise, sessionId: String, existing: [WorkoutSet], plan: PlanEntry? = nil) async -> ExerciseBlock {
        let history: [WorkoutSet] = (try? await API.get("workout_sets", query: ["exercise_id": "eq.\(ex.id)", "done": "eq.true", "order": "created_at.desc", "limit": "300"])) ?? []
        let prior = history.filter { $0.sessionId != sessionId }
        let best = prior.map { Self.score(weight: $0.weight, reps: $0.reps) }.max() ?? 0
        let lastSessionId = prior.first?.sessionId
        let last = prior.filter { $0.sessionId == lastSessionId }.sorted { $0.setNo < $1.setNo }

        var drafts: [SetDraft] = []
        if !existing.isEmpty {
            for (i, s) in existing.sorted(by: { $0.setNo < $1.setNo }).enumerated() {
                let l = last.indices.contains(i) ? last[i] : nil
                drafts.append(Self.draft(from: s, last: l))
            }
            Self.restoreRecords(in: &drafts, priorBest: best)
        } else {
            for i in 0..<(plan?.sets ?? max(last.count, 3)) {
                let exact = last.indices.contains(i) ? last[i] : nil
                let source = exact ?? last.last
                let reps = plan.map { String($0.reps) } ?? source?.reps.map(String.init) ?? ""
                drafts.append(SetDraft(weight: Self.format(source?.weight), reps: reps, done: false, lastWeight: exact?.weight, lastReps: exact?.reps))
            }
        }
        return ExerciseBlock(exercise: ex, sets: drafts, priorBest: best, plan: plan)
    }

    private static func draft(from row: WorkoutSet, last: WorkoutSet? = nil) -> SetDraft {
        SetDraft(serverId: row.id, weight: format(row.weight), reps: row.reps.map(String.init) ?? "", done: row.done,
                 lastWeight: last?.weight, lastReps: last?.reps)
    }

    private static func restoreRecords(in drafts: inout [SetDraft], priorBest: Double) {
        let scores = drafts.map { $0.done ? score(weight: Double($0.weight), reps: Int($0.reps)) : 0 }
        let best = scores.max() ?? 0
        for index in drafts.indices {
            drafts[index].isPR = drafts[index].done && scores[index] > priorBest && priorBest > 0 && scores[index] == best
        }
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

    func saveScheduleItem(id: String?, weekday: Int, title: String, plan: [PlanEntry], reminderTime: String?) async {
        let body = ScheduleWrite(weekday: weekday, title: title, exerciseIds: plan.map(\.exerciseId), plan: plan, reminderTime: reminderTime)
        do {
            if let id { try await API.patch("schedule_items", id: id, body) }
            else { _ = try await API.insert("schedule_items", body, as: ScheduleItem.self) }
            weekSchedule = try await API.get("schedule_items", query: ["order": "weekday,reminder_time"])
            errorMessage = nil
            Task { await NotificationPlanner.refresh() }
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteScheduleItem(_ id: String) async {
        do {
            try await API.delete("schedule_items", id: id)
            weekSchedule.removeAll { $0.id == id }
            errorMessage = nil
            Task { await NotificationPlanner.refresh() }
        } catch { errorMessage = error.localizedDescription }
    }
}
