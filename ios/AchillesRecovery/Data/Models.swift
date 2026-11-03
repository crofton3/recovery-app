import Foundation

// Dates are "yyyy-MM-dd" strings, matching Postgres `date` columns.

struct UserSettings: Codable {
    var id: String?
    var rehabPhase: Int?
    var surgeryDate: String?
    var calorieTarget: Int?
    var proteinTarget: Int?
    var waterTargetOz: Int?
    var injuredSide: String?
}

struct DailyLog: Codable, Identifiable {
    var id: String
    var date: String
    var itemName: String
    var calories: Int?
    var protein: Int?
}

struct DailyStatus: Codable {
    var date: String
    var waterOz: Int?
}

struct AchillesDaily: Codable {
    var date: String
    var pain: Int
    var swelling: Int
    var notes: String?
}

struct WhoopDaily: Codable {
    var date: String
    var recoveryScore: Double?
    var hrv: Double?
    var rhr: Double?
    var sleepPerformance: Double?
    var sleepHours: Double?
    var strain: Double?
}

struct ScheduleItem: Codable, Identifiable {
    var id: String
    var weekday: Int
    var title: String
    var exerciseIds: [String]?
    var reminderTime: String?
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var unit: String
}

struct NewExercise: Encodable {
    var name: String
    var category: String
    var unit: String
}

struct WorkoutSession: Codable, Identifiable {
    var id: String
    var date: String
    var title: String
    var scheduleItemId: String?
    var startedAt: String?
    var completedAt: String?
}

struct NewSession: Encodable {
    var date: String
    var title: String
    var scheduleItemId: String?
    var startedAt: String
}

struct SessionComplete: Encodable {
    var completedAt: String
}

struct WorkoutSet: Codable, Identifiable {
    var id: String
    var sessionId: String
    var exerciseId: String
    var setNo: Int
    var weight: Double?
    var reps: Int?
    var done: Bool
    var createdAt: String?
}

struct NewSet: Encodable {
    var sessionId: String
    var exerciseId: String
    var setNo: Int
    var weight: Double?
    var reps: Int?
    var done: Bool
}

struct SetUpdate: Encodable {
    var weight: Double?
    var reps: Int?
    var done: Bool
}

/// Always sends reminderTime (null clears it).
struct ScheduleWrite: Encodable {
    var weekday: Int
    var title: String
    var exerciseIds: [String]
    var reminderTime: String?

    enum CodingKeys: String, CodingKey { case weekday, title, exerciseIds, reminderTime }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(weekday, forKey: .weekday)
        try c.encode(title, forKey: .title)
        try c.encode(exerciseIds, forKey: .exerciseIds)
        try c.encode(reminderTime, forKey: .reminderTime)
    }
}

enum Day {
    static func string(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func parse(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    /// 0 = Sunday, matching schedule_items.weekday.
    static var weekday: Int { Calendar.current.component(.weekday, from: Date()) - 1 }
}

// MARK: Achilles

struct Milestone: Codable, Identifiable {
    var id: String
    var phase: Int
    var title: String
    var targetWeek: Int?
    var doneAt: String?
}

struct NewMilestone: Encodable {
    var phase: Int
    var title: String
    var targetWeek: Int?
}

/// Always sends doneAt (null marks the milestone not done).
struct MilestoneDone: Encodable {
    var doneAt: String?
    enum CodingKeys: String, CodingKey { case doneAt }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(doneAt, forKey: .doneAt)
    }
}

struct RomMeasurement: Codable, Identifiable {
    var id: String
    var date: String
    var metric: String
    var side: String
    var value: Double
}

struct NewRom: Encodable {
    var date: String
    var metric: String
    var side: String
    var value: Double
}

struct PTSession: Codable, Identifiable {
    var id: String
    var date: String
    var durationMin: Int?
    var exercises: [String]?
    var therapistNotes: String?
}

struct NewPT: Encodable {
    var date: String
    var durationMin: Int?
    var exercises: [String]
    var therapistNotes: String?
}

struct SettingsPatch: Encodable {
    var rehabPhase: Int?
    var surgeryDate: String?
}
