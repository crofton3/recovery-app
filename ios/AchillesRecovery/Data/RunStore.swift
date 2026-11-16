import Foundation
import Observation

/// One finished run. The id is made on the phone so a retried save never creates a duplicate.
struct RunRecord: Codable, Identifiable, Equatable {
    var id: String
    var date: String
    var startedAt: String
    /// Active time, pauses left out.
    var durationS: Int
    var distanceM: Double
    var runM: Double
    var walkM: Double
    var runS: Int
    var planRunM: Double?
    var planWalkM: Double?
    var planRounds: Int?
    var roundsDone: Int
    /// Achilles pain during the run, 0 to 10.
    var pain: Int?
    var notes: String?
    var segments: [RunSegment]?
    /// [[latitude, longitude]]. Left out of list queries and fetched when a run is opened.
    var route: [[Double]]?

    var started: Date? { ISO8601DateFormatter().date(from: startedAt) }

    /// Builds the record from what the tracker measured.
    static func make(plan: RunPlan, segments: [RunSegment], route: [[Double]], startedAt: Date, elapsed: TimeInterval) -> RunRecord {
        let runs = segments.filter { $0.kind == .run }
        let runM = runs.reduce(0) { $0 + $1.meters }
        let total = segments.reduce(0) { $0 + $1.meters }
        let fullRuns = runs.filter { $0.meters >= plan.runMeters - 0.5 }.count
        return RunRecord(
            id: UUID().uuidString.lowercased(), date: Day.string(startedAt), startedAt: ISO8601DateFormatter().string(from: startedAt),
            durationS: Int(elapsed.rounded()), distanceM: total, runM: runM, walkM: total - runM,
            runS: Int(runs.reduce(0) { $0 + $1.seconds }.rounded()),
            planRunM: plan.runMeters, planWalkM: plan.walkMeters, planRounds: plan.rounds,
            roundsDone: min(fullRuns, plan.rounds), pain: nil, notes: nil,
            segments: segments, route: thin(route))
    }

    /// Keeps a route to at most `limit` points, always including the last one.
    static func thin(_ route: [[Double]], limit: Int = 400) -> [[Double]] {
        guard route.count > limit, limit > 1 else { return route }
        let step = Double(route.count - 1) / Double(limit - 1)
        return (0..<limit).map { route[Int((Double($0) * step).rounded())] }
    }
}

@MainActor
@Observable
final class RunStore {
    private static let listColumns = "id,date,started_at,duration_s,distance_m,run_m,walk_m,run_s,plan_run_m,plan_walk_m,plan_rounds,rounds_done,pain,notes,segments"
    private static let planKey = "runPlan"
    private static let voiceKey = "runVoiceCues"

    var plan: RunPlan { didSet { UserDefaults.standard.set(try? JSONEncoder().encode(plan), forKey: Self.planKey) } }
    var voiceCues: Bool { didSet { UserDefaults.standard.set(voiceCues, forKey: Self.voiceKey) } }
    var runs: [RunRecord] = []
    /// Runs saved on the phone that have not reached the server yet.
    private(set) var pending: [RunRecord] = []
    var errorMessage: String?
    var loaded = false

    private let pendingURL: URL

    init(pendingURL: URL? = nil) {
        let defaults = UserDefaults.standard
        plan = defaults.data(forKey: Self.planKey).flatMap { try? JSONDecoder().decode(RunPlan.self, from: $0) } ?? RunPlan()
        voiceCues = defaults.object(forKey: Self.voiceKey) as? Bool ?? true
        self.pendingURL = pendingURL ?? URL.applicationSupportDirectory.appending(path: "pending-runs.json")
        pending = (try? Data(contentsOf: self.pendingURL)).flatMap { try? JSONDecoder().decode([RunRecord].self, from: $0) } ?? []
    }

    /// Newest first, with runs still waiting to sync on top.
    var all: [RunRecord] { pending.sorted { $0.startedAt > $1.startedAt } + runs.filter { r in !pending.contains { $0.id == r.id } } }

    func isPending(_ run: RunRecord) -> Bool { pending.contains { $0.id == run.id } }

    /// Metres covered in the last 7 days.
    var weekMeters: Double {
        let from = Day.string(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        return all.filter { $0.date >= from }.reduce(0) { $0 + $1.distanceM }
    }

    func load() async {
        await syncPending()
        do {
            runs = try await API.get("runs", query: ["select": Self.listColumns, "order": "started_at.desc", "limit": "30"])
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
        loaded = true
    }

    /// Saves a run. If the network is down it is kept on the phone and sent the next time the app loads runs.
    func save(_ run: RunRecord) async {
        do {
            try await API.upsert("runs", run, onConflict: "id")
            runs.removeAll { $0.id == run.id }
            runs.insert(run, at: 0)
            runs.sort { $0.startedAt > $1.startedAt }
            setPending(pending.filter { $0.id != run.id })
            errorMessage = nil
        } catch {
            setPending(pending.filter { $0.id != run.id } + [run])
            errorMessage = "Saved on this phone. It will sync when you are back online."
        }
    }

    func delete(_ run: RunRecord) async {
        if isPending(run) { setPending(pending.filter { $0.id != run.id }); return }
        do {
            try await API.delete("runs", id: run.id)
            runs.removeAll { $0.id == run.id }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    /// The route for a run from the list (which is loaded without routes).
    func route(for run: RunRecord) async -> [[Double]] {
        if let route = all.first(where: { $0.id == run.id })?.route ?? run.route { return route }
        struct Row: Decodable { var route: [[Double]]? }
        let rows: [Row] = (try? await API.get("runs", query: ["id": "eq.\(run.id)", "select": "route"])) ?? []
        let route = rows.first?.route ?? []
        if let i = runs.firstIndex(where: { $0.id == run.id }) { runs[i].route = route }
        return route
    }

    private func syncPending() async {
        for run in pending {
            guard (try? await API.upsert("runs", run, onConflict: "id")) != nil else { continue }
            setPending(pending.filter { $0.id != run.id })
        }
    }

    private func setPending(_ new: [RunRecord]) {
        pending = new
        try? FileManager.default.createDirectory(at: pendingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if new.isEmpty { try? FileManager.default.removeItem(at: pendingURL) }
        else { try? JSONEncoder().encode(new).write(to: pendingURL, options: .atomic) }
    }
}
