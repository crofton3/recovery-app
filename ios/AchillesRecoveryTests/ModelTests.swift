import Foundation
import Testing
@testable import AchillesRecovery

struct DayTests {
    @Test func roundTripsThroughString() throws {
        let date = try #require(Day.parse("2026-03-09"))
        #expect(Day.string(date) == "2026-03-09")
    }

    @Test(arguments: ["", "2026-13-01", "03/09/2026", "not a date"])
    func rejectsMalformedDates(_ input: String) {
        #expect(Day.parse(input) == nil)
    }

    @Test func weekdayIsZeroBasedFromSunday() {
        #expect((0...6).contains(Day.weekday))
    }
}

struct ScheduleItemTests {
    @Test func entriesPreferThePlan() {
        let plan = [PlanEntry(exerciseId: "a", sets: 4, reps: 8)]
        let item = ScheduleItem(id: "1", weekday: 1, title: "Legs", exerciseIds: ["a", "b"], plan: plan, reminderTime: nil)
        #expect(item.entries.map(\.exerciseId) == ["a"])
        #expect(item.entries.first?.plan == plan.first)
    }

    @Test func entriesFallBackToExerciseIdsWhenPlanIsEmpty() {
        let item = ScheduleItem(id: "1", weekday: 1, title: "Legs", exerciseIds: ["a", "b"], plan: [], reminderTime: nil)
        #expect(item.entries.map(\.exerciseId) == ["a", "b"])
        #expect(item.entries.allSatisfy { $0.plan == nil })
    }

    @Test func entriesAreEmptyWithNoExercises() {
        let item = ScheduleItem(id: "1", weekday: 1, title: "Rest", exerciseIds: nil, plan: nil, reminderTime: nil)
        #expect(item.entries.isEmpty)
    }
}

struct CodingTests {
    @Test func scheduleWriteSendsNullReminderToClearIt() throws {
        let body = ScheduleWrite(weekday: 2, title: "Upper", exerciseIds: ["x"], plan: [], reminderTime: nil)
        let json = try #require(try JSONSerialization.jsonObject(with: API.encoder.encode(body)) as? [String: Any])
        #expect(json.keys.contains("reminder_time"))
        #expect(json["reminder_time"] is NSNull)
        #expect(json["exercise_ids"] as? [String] == ["x"])
    }

    @Test func decodesSnakeCaseRows() throws {
        let data = Data(#"[{"id":"s1","session_id":"w1","exercise_id":"e1","set_no":2,"weight":135.5,"reps":8,"done":true}]"#.utf8)
        let sets = try API.decoder.decode([WorkoutSet].self, from: data)
        #expect(sets.first?.sessionId == "w1")
        #expect(sets.first?.setNo == 2)
        #expect(sets.first?.weight == 135.5)
    }

    @Test func decodesScheduleItemWithPlan() throws {
        let data = Data(#"[{"id":"i1","weekday":3,"title":"Legs","exercise_ids":["e1"],"plan":[{"exercise_id":"e1","sets":3,"reps":12}],"reminder_time":"18:30:00"}]"#.utf8)
        let item = try #require(try API.decoder.decode([ScheduleItem].self, from: data).first)
        #expect(item.plan == [PlanEntry(exerciseId: "e1", sets: 3, reps: 12)])
        #expect(item.reminderTime == "18:30:00")
    }
}

struct ReminderTimeTests {
    @Test func parsesPostgresTime() {
        let hm = NotificationPlanner.parse("18:30:00")
        #expect(hm?.hour == 18)
        #expect(hm?.minute == 30)
    }

    @Test func parsesHourAndMinuteOnly() {
        #expect(NotificationPlanner.parse("07:05")?.minute == 5)
    }

    @Test(arguments: ["", "18", "aa:bb", "noon"])
    func rejectsBadTimes(_ input: String) {
        #expect(NotificationPlanner.parse(input) == nil)
    }
}

@MainActor
struct MathTests {
    @Test func scoreUsesEpleyForWeightedSets() {
        #expect(TrainStore.score(weight: 100, reps: 30) == 200)
        #expect(TrainStore.score(weight: 100, reps: 0) == 100)
    }

    @Test func scoreUsesRepsForBodyweightSets() {
        #expect(TrainStore.score(weight: nil, reps: 15) == 15)
        #expect(TrainStore.score(weight: 0, reps: 12) == 12)
        #expect(TrainStore.score(weight: nil, reps: nil) == 0)
    }

    @Test func formatDropsTrailingZero() {
        #expect(TrainStore.format(135) == "135")
        #expect(TrainStore.format(42.5) == "42.5")
        #expect(TrainStore.format(nil).isEmpty)
    }

    @Test func averageHandlesEmpty() {
        #expect(TrendsStore.average([]) == nil)
        #expect(TrendsStore.average([2, 4, 9]) == 5)
    }
}
