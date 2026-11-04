import Foundation
import UserNotifications

/// Local reminders, no server needed. Rebuilt whenever the app opens or your data changes.
/// - Each scheduled workout gets a reminder at its time, for the next 14 days. Today's is skipped once you finish it.
/// - A daily Achilles check nudge at 8:00 PM. Today's is skipped once you log it.
enum NotificationPlanner {
    static let achillesHour = 20

    static func refresh() async {
        if DemoMode.isOn { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        do {
            let today = Day.string()
            let items: [ScheduleItem] = try await API.get("schedule_items")
            let doneToday: [WorkoutSession] = try await API.get("workout_sessions", query: ["date": "eq.\(today)", "completed_at": "not.is.null"])
            let achillesToday: [AchillesDaily] = try await API.get("achilles_daily", query: ["date": "eq.\(today)"])
            let doneItemIds = Set(doneToday.compactMap(\.scheduleItemId))

            center.removeAllPendingNotificationRequests()
            let cal = Calendar.current
            for offset in 0..<14 {
                guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
                let weekday = cal.component(.weekday, from: day) - 1

                for item in items where item.weekday == weekday {
                    guard let time = item.reminderTime, let hm = parse(time) else { continue }
                    if offset == 0 && doneItemIds.contains(item.id) { continue }
                    await add(id: "workout-\(item.id)-\(offset)", day: day, hour: hm.hour, minute: hm.minute,
                              title: "Today: \(item.title)", body: "Open Train to start your session.")
                }
                if !(offset == 0 && !achillesToday.isEmpty) {
                    await add(id: "achilles-\(offset)", day: day, hour: achillesHour, minute: 0,
                              title: "Log your Achilles check", body: "Pain and swelling take ten seconds.")
                }
            }
        } catch {
            // Keep whatever is already scheduled if the network is down.
        }
    }

    private static func parse(_ hhmmss: String) -> (hour: Int, minute: Int)? {
        let p = hhmmss.split(separator: ":")
        guard p.count >= 2, let h = Int(p[0]), let m = Int(p[1]) else { return nil }
        return (h, m)
    }

    private static func add(id: String, day: Date, hour: Int, minute: Int, title: String, body: String) async {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        guard let fire = Calendar.current.date(from: comps), fire > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
