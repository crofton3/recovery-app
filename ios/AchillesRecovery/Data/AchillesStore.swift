import Foundation
import Observation

struct RomMetric: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let unit: String
}

enum RehabPhases {
    /// Starting points. Edit to match your PT's protocol.
    struct Phase { let name: String; let startWeek: Int; let endWeek: Int? }
    static let all: [Phase] = [
        Phase(name: "Protect", startWeek: 0, endWeek: 2),
        Phase(name: "Load", startWeek: 2, endWeek: 6),
        Phase(name: "Strength", startWeek: 6, endWeek: 12),
        Phase(name: "Run", startWeek: 12, endWeek: 20),
        Phase(name: "Sport", startWeek: 20, endWeek: nil),
    ]
}

@MainActor
@Observable
final class AchillesStore {
    static let metrics: [RomMetric] = [
        RomMetric(key: "dorsiflexion", title: "Dorsiflexion, knee bent", unit: "°"),
        RomMetric(key: "plantarflexion_strength", title: "Push-down strength", unit: "lb"),
        RomMetric(key: "single_leg_heel_raise", title: "Single-leg heel raise", unit: "reps"),
        RomMetric(key: "double_leg_heel_raise", title: "Double-leg heel raise", unit: "reps"),
        RomMetric(key: "calf_girth", title: "Calf girth", unit: "cm"),
    ]

    var settings = UserSettings()
    var milestones: [Milestone] = []
    var daily: [AchillesDaily] = []
    var rom: [RomMeasurement] = []
    var pt: [PTSession] = []
    var errorMessage: String?
    var loaded = false

    var injured: String { settings.injuredSide ?? "L" }
    var healthy: String { injured == "L" ? "R" : "L" }
    var phase: Int { min(max(settings.rehabPhase ?? 1, 1), 5) }

    var weekPostOp: Int? {
        guard let s = settings.surgeryDate, let d = Day.parse(s) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        return max(days, 0) / 7 + 1
    }

    func load() async {
        let from = Day.string(Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date())
        var errors: [String] = []
        func attempt<T>(_ label: String, _ work: () async throws -> T) async -> T? {
            do { return try await work() } catch { errors.append("\(label): \(error.localizedDescription)"); return nil }
        }
        if let s: [UserSettings] = await attempt("settings", { try await API.get("user_settings", query: ["order": "created_at", "limit": "1"]) }) { settings = s.first ?? UserSettings() }
        if let m: [Milestone] = await attempt("milestones", { try await API.get("rehab_milestones", query: ["order": "phase,target_week"]) }) { milestones = m }
        if let d: [AchillesDaily] = await attempt("daily", { try await API.get("achilles_daily", query: ["date": "gte.\(from)", "order": "date"]) }) { daily = d }
        if let r: [RomMeasurement] = await attempt("measurements", { try await API.get("rom_measurements", query: ["order": "date.desc,created_at.desc"]) }) { rom = r }
        if let p: [PTSession] = await attempt("pt", { try await API.get("pt_sessions", query: ["order": "date.desc", "limit": "20"]) }) { pt = p }
        errorMessage = errors.first
        loaded = true
    }

    // MARK: Settings

    func setPhase(_ phase: Int) async { await save(SettingsPatch(rehabPhase: phase, surgeryDate: nil)) }
    func setSurgeryDate(_ date: Date) async { await save(SettingsPatch(rehabPhase: nil, surgeryDate: Day.string(date))) }

    private func save(_ patch: SettingsPatch) async {
        do {
            if let id = settings.id { try await API.patch("user_settings", id: id, patch) }
            else { try await API.send("POST", "user_settings", body: API.encoder.encode(patch), prefer: "return=minimal") }
            let s: [UserSettings] = try await API.get("user_settings", query: ["order": "created_at", "limit": "1"])
            settings = s.first ?? settings
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Milestones

    func toggle(_ m: Milestone) async {
        let newDone: String? = m.doneAt == nil ? Day.string() : nil
        if let i = milestones.firstIndex(where: { $0.id == m.id }) { milestones[i].doneAt = newDone }
        do {
            try await API.patch("rehab_milestones", id: m.id, MilestoneDone(doneAt: newDone))
            errorMessage = nil
        } catch {
            if let i = milestones.firstIndex(where: { $0.id == m.id }) { milestones[i].doneAt = m.doneAt }
            errorMessage = error.localizedDescription
        }
    }

    func addMilestone(title: String, phase: Int, week: Int?) async {
        do {
            let m: Milestone = try await API.insert("rehab_milestones", NewMilestone(phase: phase, title: title, targetWeek: week), as: Milestone.self)
            milestones.append(m)
            milestones.sort { ($0.phase, $0.targetWeek ?? 99) < ($1.phase, $1.targetWeek ?? 99) }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Measurements

    func latest(_ metric: String, side: String) -> RomMeasurement? {
        rom.first { $0.metric == metric && $0.side == side }  // rom is newest first
    }

    /// Injured side as a percentage of the other side, nil until both exist.
    func symmetry(_ metric: String) -> Int? {
        guard let a = latest(metric, side: injured)?.value, let b = latest(metric, side: healthy)?.value, b > 0 else { return nil }
        return Int((a / b * 100).rounded())
    }

    func logMeasurements(_ entries: [(metric: String, side: String, value: Double)]) async {
        do {
            for e in entries {
                let row: RomMeasurement = try await API.insert("rom_measurements", NewRom(date: Day.string(), metric: e.metric, side: e.side, value: e.value), as: RomMeasurement.self)
                rom.insert(row, at: 0)
            }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: PT

    func addPT(date: Date, minutes: Int?, exercises: [String], notes: String?) async {
        do {
            let s: PTSession = try await API.insert("pt_sessions", NewPT(date: Day.string(date), durationMin: minutes, exercises: exercises, therapistNotes: notes), as: PTSession.self)
            pt.append(s)
            pt.sort { $0.date > $1.date }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
