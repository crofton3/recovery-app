import Foundation

/// Demo mode: the app runs on made-up data held in memory, with no Supabase project.
/// Turn it on with the launch argument `-demoMode YES` (Xcode: Product, Scheme, Edit Scheme, Run, Arguments).
/// Nothing is saved between launches. All of this data is fake.
enum DemoMode {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "demoMode") }
}

/// A tiny stand-in for the PostgREST calls the app makes, backed by fake rows.
final class DemoBackend {
    static let shared = DemoBackend()

    private var tables: [String: [[String: Any]]] = [:]
    private let lock = NSLock()
    private let iso = ISO8601DateFormatter()
    private let cal = Calendar.current

    private init() { seed() }

    // MARK: Request handling

    func handle(method: String, table: String, query: [String: String], body: Data?, prefer: String?) -> Data {
        lock.lock(); defer { lock.unlock() }
        var rows = tables[table] ?? []

        switch method {
        case "GET":
            rows = filter(rows, query)
            rows = sort(rows, order: query["order"])
            if let limit = query["limit"].flatMap(Int.init) { rows = Array(rows.prefix(limit)) }
            if let select = query["select"], select != "*" {
                let keys = select.split(separator: ",").map(String.init)
                rows = rows.map { $0.filter { keys.contains($0.key) } }
            }
            return json(rows)

        case "POST":
            let incoming = parse(body)
            var returned: [[String: Any]] = []
            let conflictKeys = (query["on_conflict"] ?? "").split(separator: ",").map(String.init)
            for var row in incoming {
                if !conflictKeys.isEmpty, let i = tables[table, default: []].firstIndex(where: { existing in
                    conflictKeys.allSatisfy { str(existing[$0]) == str(row[$0]) }
                }) {
                    for (k, v) in row { tables[table]![i][k] = v }
                    returned.append(tables[table]![i])
                } else {
                    row["id"] = row["id"] ?? UUID().uuidString.lowercased()
                    row["created_at"] = row["created_at"] ?? iso.string(from: Date())
                    tables[table, default: []].append(row)
                    returned.append(row)
                }
            }
            return (prefer ?? "").contains("return=representation") ? json(returned) : Data("[]".utf8)

        case "PATCH":
            let patch = parse(body).first ?? [:]
            for i in tables[table, default: []].indices where matchesAll(tables[table]![i], query) {
                for (k, v) in patch { tables[table]![i][k] = v }
            }
            return Data("[]".utf8)

        case "DELETE":
            tables[table]?.removeAll { matchesAll($0, query) }
            return Data("[]".utf8)

        default:
            return Data("[]".utf8)
        }
    }

    // MARK: Query helpers

    private func matchesAll(_ row: [String: Any], _ query: [String: String]) -> Bool {
        let reserved: Set<String> = ["order", "limit", "select", "on_conflict"]
        return query.allSatisfy { reserved.contains($0.key) || matches(row, key: $0.key, expr: $0.value) }
    }

    private func filter(_ rows: [[String: Any]], _ query: [String: String]) -> [[String: Any]] {
        rows.filter { matchesAll($0, query) }
    }

    private func matches(_ row: [String: Any], key: String, expr: String) -> Bool {
        let value = row[key]
        let isNull = value == nil || value is NSNull
        if expr == "is.null" { return isNull }
        if expr == "not.is.null" { return !isNull }
        if expr.hasPrefix("eq.") { return str(value) == String(expr.dropFirst(3)) }
        if expr.hasPrefix("gte.") { return compare(str(value), String(expr.dropFirst(4))) >= 0 }
        return true
    }

    private func sort(_ rows: [[String: Any]], order: String?) -> [[String: Any]] {
        guard let order else { return rows }
        let keys = order.split(separator: ",").map { part -> (String, Bool) in
            let bits = part.split(separator: ".").map(String.init)
            return (bits[0], bits.count > 1 && bits[1] == "desc")
        }
        return rows.enumerated().sorted { a, b in
            for (key, desc) in keys {
                let c = compare(str(a.element[key]), str(b.element[key]))
                if c != 0 { return desc ? c > 0 : c < 0 }
            }
            return a.offset < b.offset
        }.map(\.element)
    }

    private func compare(_ a: String, _ b: String) -> Int {
        if let x = Double(a), let y = Double(b) { return x == y ? 0 : (x < y ? -1 : 1) }
        return a == b ? 0 : (a < b ? -1 : 1)
    }

    private func str(_ v: Any?) -> String {
        switch v {
        case let s as String: return s
        case let b as Bool: return b ? "true" : "false"
        case let i as Int: return String(i)
        case let d as Double: return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(d)
        default: return ""
        }
    }

    private func parse(_ data: Data?) -> [[String: Any]] {
        guard let data, let obj = try? JSONSerialization.jsonObject(with: data) else { return [] }
        if let arr = obj as? [[String: Any]] { return arr }
        if let one = obj as? [String: Any] { return [one] }
        return []
    }

    private func json(_ rows: [[String: Any]]) -> Data {
        (try? JSONSerialization.data(withJSONObject: rows)) ?? Data("[]".utf8)
    }

    // MARK: Fake data

    private func day(_ daysAgo: Int) -> String {
        Day.string(cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date())
    }

    private func ts(_ daysAgo: Int, hour: Int = 18, minute: Int = 30) -> String {
        let base = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return iso.string(from: cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base)
    }

    private func add(_ table: String, _ rows: [[String: Any]]) {
        for var row in rows {
            row["id"] = row["id"] ?? UUID().uuidString.lowercased()
            tables[table, default: []].append(row)
        }
    }

    // swiftlint:disable:next function_body_length
    private func seed() {
        // Exercises
        func ex(_ name: String, _ category: String, _ unit: String) -> String {
            let id = UUID().uuidString.lowercased()
            add("exercises", [["id": id, "name": name, "category": category, "unit": unit, "created_at": ts(60)]])
            return id
        }
        let legPress = ex("Leg press", "lower", "lb")
        let calfRaise = ex("Seated calf raise", "rehab", "lb")
        let rdl = ex("Romanian deadlift", "lower", "lb")
        let balance = ex("Single-leg balance", "rehab", "sec")
        let heelRaise = ex("Double-leg heel raise", "rehab", "bodyweight")
        let bench = ex("Bench press", "upper", "lb")
        let row = ex("Cable row", "upper", "lb")
        let press = ex("Shoulder press", "upper", "lb")

        // Settings (surgery about 10 weeks ago, left Achilles)
        add("user_settings", [[
            "surgery_date": day(68), "rehab_phase": 3, "injured_side": "L",
            "calorie_target": 2500, "protein_target": 180, "water_target_oz": 100, "created_at": ts(70)
        ]])

        // Weekly schedule: today is a lower-body day
        let dow = Day.weekday
        func plan(_ entries: [(String, Int, Int)]) -> [[String: Any]] {
            entries.map { ["exercise_id": $0.0, "sets": $0.1, "reps": $0.2] }
        }
        let lowerPlan = plan([(legPress, 3, 10), (calfRaise, 3, 15), (rdl, 3, 10), (heelRaise, 3, 15), (balance, 3, 30)])
        let upperPlan = plan([(bench, 3, 8), (row, 3, 10), (press, 3, 8)])
        func item(_ offset: Int, _ title: String, _ time: String, _ p: [[String: Any]]) -> [String: Any] {
            ["weekday": (dow + offset) % 7, "title": title, "reminder_time": time,
             "exercise_ids": p.compactMap { $0["exercise_id"] as? String }, "plan": p, "created_at": ts(60)]
        }
        add("schedule_items", [
            item(0, "Lower body + calf rehab", "18:30:00", lowerPlan),
            item(1, "Upper body", "18:30:00", upperPlan),
            item(2, "Physical therapy", "08:00:00", []),
            item(4, "Lower body + calf rehab", "18:30:00", lowerPlan),
            item(5, "Upper body", "09:00:00", upperPlan),
        ])

        // Past lower-body sessions, getting heavier each week
        for week in stride(from: 6, through: 1, by: -1) {
            let sid = UUID().uuidString.lowercased()
            let started = ts(week * 7 - 1, hour: 18, minute: 35)
            add("workout_sessions", [["id": sid, "date": day(week * 7 - 1), "title": "Lower body + calf rehab",
                                       "started_at": started, "completed_at": ts(week * 7 - 1, hour: 19, minute: 20), "created_at": started]])
            let step = 7 - week
            for n in 1...3 {
                add("workout_sets", [
                    ["session_id": sid, "exercise_id": legPress, "set_no": n, "weight": 120 + step * 10, "reps": 10, "done": true, "created_at": started],
                    ["session_id": sid, "exercise_id": calfRaise, "set_no": n, "weight": 30 + step * 4, "reps": 15, "done": true, "created_at": started],
                    ["session_id": sid, "exercise_id": rdl, "set_no": n, "weight": 65 + step * 5, "reps": 10, "done": true, "created_at": started],
                ])
            }
        }
        // Past upper-body sessions (for the training dots on Trends)
        for ago in [2, 5, 9, 12, 16, 19, 23, 26] {
            let started = ts(ago, hour: 9, minute: 0)
            add("workout_sessions", [["date": day(ago), "title": "Upper body", "started_at": started,
                                       "completed_at": ts(ago, hour: 9, minute: 50), "created_at": started]])
        }

        // Today's workout, already in progress
        let live = UUID().uuidString.lowercased()
        let liveStart = iso.string(from: Date().addingTimeInterval(-22 * 60))
        add("workout_sessions", [["id": live, "date": day(0), "title": "Lower body + calf rehab",
                                   "started_at": liveStart, "created_at": liveStart]])
        let t0 = Date().addingTimeInterval(-21 * 60)
        func liveSet(_ exId: String, _ n: Int, _ weight: Double?, _ reps: Int, _ done: Bool, _ offset: Double) -> [String: Any] {
            var s: [String: Any] = ["session_id": live, "exercise_id": exId, "set_no": n, "reps": reps, "done": done,
                                    "created_at": iso.string(from: t0.addingTimeInterval(offset))]
            if let weight { s["weight"] = weight }
            return s
        }
        add("workout_sets", [
            liveSet(legPress, 1, 180, 10, true, 0), liveSet(legPress, 2, 190, 10, true, 1), liveSet(legPress, 3, 190, 8, false, 2),
            liveSet(calfRaise, 1, 60, 15, true, 3), liveSet(calfRaise, 2, 60, 15, false, 4), liveSet(calfRaise, 3, 60, 15, false, 5),
        ])

        // WHOOP, 30 days
        for ago in 0..<30 {
            let x = Double(ago)
            add("whoop_daily", [[
                "date": day(ago),
                "recovery_score": max(28, (68 + 22 * sin(x * 0.8)).rounded()),
                "hrv": (82 + 14 * sin(x * 0.8)).rounded(),
                "rhr": 47 + Int((3 * cos(x)).rounded()),
                "sleep_performance": (86 + 8 * cos(x * 0.6)).rounded(),
                "sleep_hours": ((7.1 + 0.9 * cos(x * 0.6)) * 100).rounded() / 100,
                "strain": ((9.5 + 4.5 * abs(sin(x * 0.7))) * 10).rounded() / 10,
            ]])
        }

        // Achilles: pain and swelling easing over two weeks, none logged yet today
        let pain = [5, 5, 4, 5, 4, 4, 3, 4, 3, 3, 3, 2, 3, 2]
        let swelling = [6, 5, 5, 5, 4, 4, 4, 3, 4, 3, 3, 3, 2, 2]
        for i in 0..<14 {
            add("achilles_daily", [["date": day(14 - i), "pain": pain[i], "swelling": swelling[i], "created_at": ts(14 - i, hour: 20)]])
        }

        func milestone(_ phase: Int, _ title: String, _ week: Int, done: Int?) -> [String: Any] {
            var m: [String: Any] = ["phase": phase, "title": title, "target_week": week, "created_at": ts(60)]
            if let done { m["done_at"] = day(done) }
            return m
        }
        add("rehab_milestones", [
            milestone(2, "Out of the boot", 6, done: 26),
            milestone(3, "Walk without a limp", 7, done: 21),
            milestone(3, "Double-leg heel raise x 10", 8, done: 14),
            milestone(3, "Single-leg balance 30 s", 9, done: 6),
            milestone(3, "Double-leg heel raise x 25", 11, done: nil),
            milestone(3, "Single-leg heel raise x 10", 12, done: nil),
            milestone(4, "Cleared to start jogging", 14, done: nil),
        ])

        // Left (injured) vs right measurements at four visits
        let visits: [(Int, [String: (Double, Double)])] = [
            (42, ["dorsiflexion": (6, 20), "plantarflexion_strength": (22, 82), "single_leg_heel_raise": (0, 26), "double_leg_heel_raise": (6, 30), "calf_girth": (34.0, 38.0)]),
            (28, ["dorsiflexion": (8, 20), "plantarflexion_strength": (30, 82), "single_leg_heel_raise": (0, 26), "double_leg_heel_raise": (10, 30), "calf_girth": (34.6, 38.0)]),
            (14, ["dorsiflexion": (10, 20), "plantarflexion_strength": (38, 83), "single_leg_heel_raise": (2, 26), "double_leg_heel_raise": (14, 30), "calf_girth": (35.2, 38.0)]),
            (1, ["dorsiflexion": (12, 20), "plantarflexion_strength": (46, 83), "single_leg_heel_raise": (4, 27), "double_leg_heel_raise": (18, 30), "calf_girth": (35.8, 38.0)]),
        ]
        for (ago, metrics) in visits {
            for (metric, pair) in metrics {
                add("rom_measurements", [
                    ["date": day(ago), "metric": metric, "side": "L", "value": pair.0, "created_at": ts(ago, hour: 10)],
                    ["date": day(ago), "metric": metric, "side": "R", "value": pair.1, "created_at": ts(ago, hour: 10)],
                ])
            }
        }

        add("pt_sessions", [
            ["date": day(3), "duration_min": 45, "exercises": ["Balance", "Calf raises"],
             "therapist_notes": "Single-leg balance on foam, 3 x 30 s. Added seated calf raise. Keep pain under 3 during exercises."],
            ["date": day(10), "duration_min": 45, "exercises": ["Gait", "Range of motion"],
             "therapist_notes": "Heel-to-toe gait drills. Dorsiflexion measured at 10 degrees. Walking 30 minutes a day is fine."],
            ["date": day(17), "duration_min": 40, "exercises": ["Strength", "Bike"],
             "therapist_notes": "Double-leg heel raises to 10. Started the stationary bike with no resistance."],
        ])

        // Food: today so far, plus earlier days for the quick-add chips
        func food(_ ago: Int, _ name: String, _ cal: Int, _ pro: Int, hour: Int) -> [String: Any] {
            ["date": day(ago), "item_name": name, "calories": cal, "protein": pro, "carbs": 0, "fat": 0, "created_at": ts(ago, hour: hour, minute: 0)]
        }
        add("daily_logs", [
            food(0, "Greek yogurt with berries", 240, 15, hour: 7), food(0, "Eggs x 3 on toast", 410, 22, hour: 8),
            food(0, "Chicken rice bowl", 620, 35, hour: 12), food(0, "Whey shake", 150, 24, hour: 15),
            food(1, "Salmon, rice and broccoli", 640, 42, hour: 19), food(1, "Banana", 105, 1, hour: 10), food(1, "Cottage cheese", 180, 24, hour: 21),
            food(2, "Turkey sandwich", 480, 32, hour: 13), food(2, "Protein bar", 210, 20, hour: 16),
        ])
        add("daily_status", [["date": day(0), "water_oz": 64, "created_at": ts(0, hour: 8)]])

        // Body check-ins every two weeks
        for i in 0..<8 {
            add("checkins", [["date": day(98 - i * 14), "body_weight": 192.4 - Double(i) * 0.5, "waist": 34.5 - Double(i) * 0.12, "created_at": ts(98 - i * 14, hour: 8)]])
        }
    }
}
