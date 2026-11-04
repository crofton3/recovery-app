import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var settings = UserSettings()
    var whoop: WhoopDaily?
    var logs: [DailyLog] = []
    var waterOz = 0
    var schedule: [ScheduleItem] = []
    var pain = 0
    var swelling = 0
    var achillesLogged = false
    var errorMessage: String?
    var loaded = false
    var whoopConnected: Bool?
    var whoopMessage: String?
    var syncing = false
    private let connector = WhoopConnector()

    var calories: Int { FuelMath.totals(logs).calories }
    var protein: Int { FuelMath.totals(logs).protein }
    var calorieTarget: Int { settings.calorieTarget ?? 2550 }
    var proteinTarget: Int { settings.proteinTarget ?? 190 }
    var waterTarget: Int { settings.waterTargetOz ?? 110 }

    /// Weeks since surgery, counting the first week as week 1. Nil until a surgery date is set.
    var weekPostOp: Int? {
        guard let s = settings.surgeryDate, let d = Day.parse(s) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        return max(days, 0) / 7 + 1
    }

    func refresh() async {
        let today = Day.string()
        var errors: [String] = []

        func attempt<T>(_ label: String, _ work: () async throws -> T) async -> T? {
            do { return try await work() } catch { errors.append("\(label): \(error.localizedDescription)"); return nil }
        }

        if let s: [UserSettings] = await attempt("settings", { try await API.get("user_settings", query: ["order": "created_at", "limit": "1"]) }) {
            settings = s.first ?? UserSettings()
        }
        if let w: [WhoopDaily] = await attempt("whoop", { try await API.get("whoop_daily", query: ["order": "date.desc", "limit": "1"]) }) {
            whoop = w.first
        }
        if let l: [DailyLog] = await attempt("food", { try await API.get("daily_logs", query: ["date": "eq.\(today)", "order": "created_at"]) }) {
            logs = l
        }
        if let st: [DailyStatus] = await attempt("water", { try await API.get("daily_status", query: ["date": "eq.\(today)"]) }) {
            waterOz = st.first?.waterOz ?? 0
        }
        if let sc: [ScheduleItem] = await attempt("schedule", { try await API.get("schedule_items", query: ["weekday": "eq.\(Day.weekday)", "order": "reminder_time"]) }) {
            schedule = sc
        }
        if let a: [AchillesDaily] = await attempt("achilles", { try await API.get("achilles_daily", query: ["date": "eq.\(today)"]) }) {
            if let first = a.first { pain = first.pain; swelling = first.swelling; achillesLogged = true }
        }
        errorMessage = errors.first
        loaded = true
    }

    func saveAchilles() async {
        do {
            try await API.upsert("achilles_daily", AchillesDaily(date: Day.string(), pain: pain, swelling: swelling, notes: nil), onConflict: "date")
            achillesLogged = true
            errorMessage = nil
            Task { await NotificationPlanner.refresh() }
        } catch { errorMessage = error.localizedDescription }
    }

    func addWater(_ oz: Int) async {
        let previous = waterOz
        waterOz += oz  // optimistic
        do {
            try await API.upsert("daily_status", DailyStatus(date: Day.string(), waterOz: waterOz), onConflict: "date")
            errorMessage = nil
        } catch {
            waterOz = previous
            errorMessage = error.localizedDescription
        }
    }

    // MARK: WHOOP

    private struct SyncResult: Decodable {
        var ok: Bool
        var connected: Bool?
        var rows: Int?
        var error: String?
    }

    /// Pulls fresh WHOOP data through the server. `quiet` skips messages (used on launch).
    func syncWhoop(days: Int = 14, quiet: Bool = false) async {
        syncing = true
        defer { syncing = false }
        do {
            let data = try await API.callFunction("whoop-sync", body: ["days": days])
            let r = try JSONDecoder().decode(SyncResult.self, from: data)
            if r.ok, r.connected == true {
                whoopConnected = true
                whoopMessage = nil
                await refresh()
            } else if r.ok {
                whoopConnected = false
                if !quiet { whoopMessage = "WHOOP isn't connected yet." }
            } else if !quiet {
                whoopMessage = r.error ?? "WHOOP sync failed."
            }
        } catch {
            if !quiet { whoopMessage = error.localizedDescription }
        }
    }

    func connectWhoop() async {
        whoopMessage = nil
        if await connector.connect() {
            await syncWhoop(days: 30)
        } else {
            whoopMessage = "WHOOP sign-in didn't finish. Check the WHOOP app setup, then try again."
        }
    }
}
