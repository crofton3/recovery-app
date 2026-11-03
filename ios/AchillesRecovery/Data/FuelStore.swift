import Foundation
import Observation

struct NewLog: Encodable {
    var date: String
    var itemName: String
    var calories: Int
    var protein: Int
}

struct TargetsPatch: Encodable {
    var calorieTarget: Int
    var proteinTarget: Int
    var waterTargetOz: Int
}

enum FuelMath {
    static let endOfDayName = "End-of-day total"

    /// If an end-of-day total exists it stands in for the individual foods (which stay saved).
    static func totals(_ logs: [DailyLog]) -> (calories: Int, protein: Int, usesEndOfDay: Bool) {
        if let eod = logs.last(where: { $0.itemName == endOfDayName }) {
            return (eod.calories ?? 0, eod.protein ?? 0, true)
        }
        return (logs.reduce(0) { $0 + ($1.calories ?? 0) }, logs.reduce(0) { $0 + ($1.protein ?? 0) }, false)
    }
}

@MainActor
@Observable
final class FuelStore {
    var date = Date()
    var logs: [DailyLog] = []
    var recents: [DailyLog] = []
    var settings = UserSettings()
    var errorMessage: String?

    var dayString: String { Day.string(date) }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var totals: (calories: Int, protein: Int, usesEndOfDay: Bool) { FuelMath.totals(logs) }
    var calorieTarget: Int { settings.calorieTarget ?? 2550 }
    var proteinTarget: Int { settings.proteinTarget ?? 190 }
    var waterTarget: Int { settings.waterTargetOz ?? 110 }
    var foods: [DailyLog] { logs.filter { $0.itemName != FuelMath.endOfDayName } }
    var endOfDay: DailyLog? { logs.last { $0.itemName == FuelMath.endOfDayName } }

    func load() async {
        do {
            settings = try await API.get("user_settings", query: ["order": "created_at", "limit": "1"], as: UserSettings.self).first ?? UserSettings()
            logs = try await API.get("daily_logs", query: ["date": "eq.\(dayString)", "order": "created_at"])
            let recent: [DailyLog] = try await API.get("daily_logs", query: ["order": "created_at.desc", "limit": "120"])
            var seen = Set<String>()
            recents = recent.filter { $0.itemName != FuelMath.endOfDayName && seen.insert($0.itemName.lowercased()).inserted }.prefix(8).map { $0 }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func shift(days: Int) async {
        guard let d = Calendar.current.date(byAdding: .day, value: days, to: date), d <= Date() else { return }
        date = d
        await load()
    }

    func add(name: String, calories: Int, protein: Int) async {
        do {
            let row: DailyLog = try await API.insert("daily_logs", NewLog(date: dayString, itemName: name, calories: calories, protein: protein), as: DailyLog.self)
            logs.append(row)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func delete(_ log: DailyLog) async {
        let before = logs
        logs.removeAll { $0.id == log.id }
        do {
            try await API.delete("daily_logs", id: log.id)
            errorMessage = nil
        } catch { logs = before; errorMessage = error.localizedDescription }
    }

    func setEndOfDay(calories: Int, protein: Int) async {
        do {
            if let existing = endOfDay { try await API.delete("daily_logs", id: existing.id); logs.removeAll { $0.id == existing.id } }
            let row: DailyLog = try await API.insert("daily_logs", NewLog(date: dayString, itemName: FuelMath.endOfDayName, calories: calories, protein: protein), as: DailyLog.self)
            logs.append(row)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func saveTargets(calories: Int, protein: Int, water: Int) async {
        do {
            guard let id = settings.id else { errorMessage = "No settings row found."; return }
            try await API.patch("user_settings", id: id, TargetsPatch(calorieTarget: calories, proteinTarget: protein, waterTargetOz: water))
            settings.calorieTarget = calories; settings.proteinTarget = protein; settings.waterTargetOz = water
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
