import Foundation

extension TrainStore {
    /// One exercise in a finished workout, with the sets that were checked off.
    struct LoggedExercise: Identifiable {
        var id: String { exerciseId }
        var exerciseId: String
        var sets: [WorkoutSet]
    }

    /// A finished workout for the history list.
    struct HistoryEntry: Identifiable {
        var id: String { session.id }
        var session: WorkoutSession
        var exercises: [LoggedExercise]
        var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
        var started: Date? { TrainStore.date(session.startedAt) }
        var duration: TimeInterval? {
            guard let start = started, let end = TrainStore.date(session.completedAt) else { return nil }
            return max(0, end.timeIntervalSince(start))
        }
    }

    // MARK: History

    /// Loads finished workouts on or after `since` (yyyy-MM-dd) and the sets checked off in each.
    /// With no date it reloads the range already loaded, or this month.
    func loadHistory(since: String? = nil) async {
        let from = [since, historySince].compactMap { $0 }.min() ?? Self.monthStart(Date())
        do {
            let sessions: [WorkoutSession] = try await API.get("workout_sessions", query: [
                "completed_at": "not.is.null", "date": "gte.\(from)", "order": "date.desc,started_at.desc", "limit": "500",
            ])
            // Ask for a few sessions at a time so the URL stays short, and read every page of each answer.
            var sets: [WorkoutSet] = []
            let ids = sessions.map(\.id)
            for start in stride(from: 0, to: ids.count, by: 40) {
                let chunk = ids[start..<min(start + 40, ids.count)]
                sets += try await Self.getAll("workout_sets", query: [
                    "session_id": "in.(\(chunk.joined(separator: ",")))", "done": "eq.true", "order": "created_at,id",
                ])
            }
            history = sessions.map { s in Self.entry(s, sets: sets.filter { $0.sessionId == s.id }) }
            historySince = from
            historyLoaded = true
        } catch { errorMessage = error.localizedDescription }
    }

    nonisolated static func monthStart(_ date: Date) -> String {
        let cal = Calendar.current
        return Day.string(cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date)
    }

    /// How each exercise in a finished workout compares with the session before it.
    struct Progress {
        /// The strongest set in this workout.
        var top: WorkoutSet?
        /// The strongest set the previous time this exercise was done.
        var previous: WorkoutSet?
        /// Beat every earlier session.
        var isPR: Bool
    }

    func progress(for entry: HistoryEntry) async -> [String: Progress] {
        var result: [String: Progress] = [:]
        let firstLogged = entry.exercises.flatMap(\.sets).compactMap(\.createdAt).min()
        // Written in UTC with a Z, since a "+" in an offset would be read as a space in the URL.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cutoff = firstLogged.flatMap { Self.date($0) }.map { formatter.string(from: $0) }
        for logged in entry.exercises {
            // Only sets from before this workout matter, and all of them, so the best and the previous session are right.
            var query = ["exercise_id": "eq.\(logged.exerciseId)", "done": "eq.true", "order": "created_at.desc,id"]
            if let cutoff { query["created_at"] = "lt.\(cutoff)" }
            let rows: [WorkoutSet] = (try? await Self.getAll("workout_sets", query: query)) ?? []
            result[logged.exerciseId] = Self.progress(logged.sets, history: rows, sessionId: entry.id, before: firstLogged)
        }
        return result
    }

    /// `history` is every done set for the exercise, newest first. Only sets from other sessions logged earlier count.
    nonisolated static func progress(_ sets: [WorkoutSet], history: [WorkoutSet], sessionId: String, before: String?) -> Progress {
        let prior = history.filter { row in
            guard row.sessionId != sessionId else { return false }
            guard let before, let created = row.createdAt else { return true }
            return (date(created) ?? .distantPast) < (date(before) ?? .distantFuture)
        }
        func best(_ rows: [WorkoutSet]) -> WorkoutSet? { rows.max { score(weight: $0.weight, reps: $0.reps) < score(weight: $1.weight, reps: $1.reps) } }
        let top = best(sets)
        let lastSession = prior.first?.sessionId
        let previous = best(prior.filter { $0.sessionId == lastSession })
        let priorBest = prior.map { score(weight: $0.weight, reps: $0.reps) }.max() ?? 0
        let isPR = top.map { priorBest > 0 && score(weight: $0.weight, reps: $0.reps) > priorBest } ?? false
        return Progress(top: top, previous: previous, isPR: isPR)
    }

    /// Reads every row a query matches, a page at a time, because the API caps one response at 1,000 rows.
    /// The query needs an order that never ties, so pages don't overlap or skip rows.
    private static func getAll<T: Decodable>(_ table: String, query: [String: String]) async throws -> [T] {
        let pageSize = 1000
        var all: [T] = []
        while true {
            var page = query
            page["limit"] = String(pageSize)
            page["offset"] = String(all.count)
            let rows: [T] = try await API.get(table, query: page)
            all += rows
            if rows.count < pageSize { return all }
        }
    }

    func deleteWorkout(_ id: String) async {
        do {
            try await API.delete("workout_sessions", id: id)
            history.removeAll { $0.id == id }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    /// Groups a session's sets by exercise, in the order the exercises were first logged.
    nonisolated static func entry(_ session: WorkoutSession, sets: [WorkoutSet]) -> HistoryEntry {
        var order: [String] = []
        for set in sets where !order.contains(set.exerciseId) { order.append(set.exerciseId) }
        let exercises = order.map { id in
            LoggedExercise(exerciseId: id, sets: sets.filter { $0.exerciseId == id }.sorted { $0.setNo < $1.setNo })
        }
        return HistoryEntry(session: session, exercises: exercises)
    }
}
