import Foundation
import Observation

struct Checkin: Codable, Identifiable {
    var id: String
    var date: String
    var bodyWeight: Double?
    var waist: Double?
}

struct SessionDay: Codable {
    var date: String
}

@MainActor
@Observable
final class TrendsStore {
    var rangeDays = 30
    var whoop: [WhoopDaily] = []
    var trainingDays: Set<String> = []
    var checkins: [Checkin] = []
    var errorMessage: String?

    var from: Date { Calendar.current.date(byAdding: .day, value: -(rangeDays - 1), to: Date()) ?? Date() }

    func load() async {
        let start = Day.string(from)
        do {
            whoop = try await API.get("whoop_daily", query: ["date": "gte.\(start)", "order": "date"])
            let days: [SessionDay] = try await API.get("workout_sessions", query: ["date": "gte.\(start)", "completed_at": "not.is.null", "select": "date"])
            trainingDays = Set(days.map(\.date))
            checkins = try await API.get("checkins", query: ["order": "date", "limit": "60"])
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func setRange(_ days: Int) async {
        rangeDays = days
        await load()
    }

    static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
