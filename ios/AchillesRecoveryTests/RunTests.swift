import Foundation
import Testing
@testable import AchillesRecovery

struct RunEngineTests {
    let mile = RunPlan.metersPerMile

    @Test func switchesBetweenRunAndWalkByDistance() {
        var engine = RunEngine(plan: RunPlan(runMiles: 0.3, walkMiles: 0.1, rounds: 2))
        #expect(engine.advance(meters: 0.29 * mile, elapsed: 170).isEmpty)
        #expect(engine.kind == .run)
        #expect(engine.advance(meters: 0.02 * mile, elapsed: 180) == [.walk])
        #expect(engine.kind == .walk)
        // The overshoot carries into the walk.
        #expect(abs(engine.segmentMeters - 0.01 * mile) < 0.001)
        #expect(engine.advance(meters: 0.095 * mile, elapsed: 240) == [.run(round: 2)])
        #expect(engine.round == 2)
        #expect(engine.completed.map(\.kind) == [.run, .walk])
        // Each boundary is timed by how far into the update it fell, not by when the update arrived.
        #expect(abs(engine.completed[0].seconds - 175) < 0.01)
        #expect(abs(engine.completed[1].seconds - (60 * 0.09 / 0.095 + 5)) < 0.01)
    }

    @Test func finishesThePlanThenCoolsDown() {
        var engine = RunEngine(plan: RunPlan(runMiles: 0.3, walkMiles: 0.1, rounds: 1))
        #expect(engine.advance(meters: 0.3 * mile, elapsed: 180) == [.walk])
        #expect(engine.advance(meters: 0.1 * mile, elapsed: 240) == [.planComplete])
        #expect(engine.planComplete)
        #expect(engine.remaining == nil)
        #expect(engine.advance(meters: 500, elapsed: 600).isEmpty)
        #expect(engine.segments(elapsed: 600).map(\.kind) == [.run, .walk, .cooldown])
        #expect(abs(engine.totalMeters - (0.4 * mile + 500)) < 0.001)
    }

    @Test func noWalkBreaksGoesRunToRun() {
        var engine = RunEngine(plan: RunPlan(runMiles: 0.5, walkMiles: 0, rounds: 2))
        #expect(engine.advance(meters: 0.5 * mile, elapsed: 300) == [.run(round: 2)])
        #expect(engine.advance(meters: 0.5 * mile, elapsed: 600) == [.planComplete])
    }

    @Test func oneBigJumpCanCrossSeveralIntervals() {
        var engine = RunEngine(plan: RunPlan(runMiles: 0.05, walkMiles: 0.05, rounds: 2))
        #expect(engine.advance(meters: 0.16 * mile, elapsed: 100) == [.walk, .run(round: 2), .walk])
        // The 100 seconds are shared out by distance: 0.05 of 0.16 miles each.
        #expect(engine.completed.allSatisfy { abs($0.seconds - 31.25) < 0.01 })
        #expect(abs(engine.segmentSeconds(elapsed: 100) - 6.25) < 0.01)
    }

    @Test func timeIsNotLostOrDoubleCountedAcrossUpdates() {
        var engine = RunEngine(plan: RunPlan(runMiles: 0.1, walkMiles: 0.05, rounds: 3))
        var elapsed = 0.0
        for step in 1...200 {
            elapsed += step.isMultiple(of: 7) ? 9 : 1  // an occasional GPS gap
            _ = engine.advance(meters: step.isMultiple(of: 7) ? 31 : 3.3, elapsed: elapsed)
        }
        let total = engine.segments(elapsed: elapsed).reduce(0) { $0 + $1.seconds }
        #expect(abs(total - elapsed) < 0.001)
        #expect(engine.completed.allSatisfy { $0.seconds > 0 })
    }

    @Test func progressAndRemainingTrackTheCurrentInterval() {
        var engine = RunEngine(plan: RunPlan(runMiles: 0.3, walkMiles: 0.1, rounds: 4))
        _ = engine.advance(meters: 0.15 * mile, elapsed: 90)
        #expect(abs(engine.progress - 0.5) < 0.0001)
        #expect(abs((engine.remaining ?? 0) - 0.15 * mile) < 0.001)
    }
}

struct GPSFilterTests {
    /// About 1.11 m of northing per 0.00001 degrees of latitude.
    private func sample(north meters: Double, t: TimeInterval, accuracy: Double = 5) -> GPSFilter.Sample {
        GPSFilter.Sample(lat: 40 + meters / 111_195, lon: -74, accuracy: accuracy, time: t)
    }

    @Test func firstGoodFixIsTheAnchor() {
        var filter = GPSFilter()
        #expect(filter.accept(sample(north: 0, t: 0, accuracy: 60)) == nil)
        #expect(filter.accept(sample(north: 0, t: 1, accuracy: -1)) == nil)
        #expect(filter.accept(sample(north: 0, t: 2)) == 0)
    }

    @Test func addsUpSteadyMovement() throws {
        var filter = GPSFilter()
        var total = 0.0
        for i in 0...100 { total += filter.accept(sample(north: Double(i) * 3.2, t: Double(i))) ?? 0 }
        #expect(abs(total - 320) < 1)
    }

    @Test func ignoresJitterButKeepsSlowProgress() {
        var filter = GPSFilter()
        _ = filter.accept(sample(north: 0, t: 0))
        #expect(filter.accept(sample(north: 1, t: 1)) == nil)
        #expect(filter.accept(sample(north: 2, t: 2)) == nil)
        // Measured from the anchor, not the dropped fixes.
        let d = filter.accept(sample(north: 3.5, t: 3))
        #expect(d != nil && abs((d ?? 0) - 3.5) < 0.05)
    }

    @Test func dropsImpossibleJumpsAndBadAccuracy() {
        var filter = GPSFilter()
        _ = filter.accept(sample(north: 0, t: 0))
        #expect(filter.accept(sample(north: 200, t: 1)) == nil)
        #expect(filter.accept(sample(north: 4, t: 2, accuracy: 80)) == nil)
        #expect(filter.accept(sample(north: 4, t: 2)) != nil)
    }

    @Test func resetForgetsTheGap() {
        var filter = GPSFilter()
        _ = filter.accept(sample(north: 0, t: 0))
        filter.reset()
        #expect(filter.accept(sample(north: 300, t: 600)) == 0)
    }
}

struct RunFormatTests {
    @Test func formatsDistanceTimeAndPace() {
        #expect(RunFormat.miles(RunPlan.metersPerMile * 0.3) == "0.30")
        #expect(RunFormat.planMiles(0.3) == "0.3")
        #expect(RunFormat.planMiles(0.25) == "0.25")
        #expect(RunFormat.planMiles(1) == "1")
        #expect(RunFormat.planMiles(1.6) == "1.6")
        #expect(RunFormat.duration(65) == "1:05")
        #expect(RunFormat.duration(3725) == "1:02:05")
        #expect(RunFormat.pace(meters: RunPlan.metersPerMile, seconds: 600) == "10:00")
        #expect(RunFormat.pace(meters: 5, seconds: 60) == "--")
    }
}

struct RunRecordTests {
    @Test func buildsTotalsFromSegments() {
        let plan = RunPlan(runMiles: 0.3, walkMiles: 0.1, rounds: 4)
        let segments = [
            RunSegment(kind: .run, meters: plan.runMeters, seconds: 180),
            RunSegment(kind: .walk, meters: plan.walkMeters, seconds: 110),
            RunSegment(kind: .run, meters: 200, seconds: 80),
        ]
        let run = RunRecord.make(plan: plan, segments: segments, route: [[1, 2], [3, 4]], startedAt: Date(timeIntervalSince1970: 1_800_000_000), elapsed: 370)
        #expect(run.roundsDone == 1)
        #expect(run.runS == 260)
        #expect(run.durationS == 370)
        #expect(abs(run.runM - (plan.runMeters + 200)) < 0.001)
        #expect(abs(run.walkM - plan.walkMeters) < 0.001)
        #expect(run.route?.count == 2)
    }

    @Test func thinsLongRoutesAndKeepsTheEnds() {
        let route = (0..<1000).map { [Double($0), 0] }
        let thin = RunRecord.thin(route, limit: 100)
        #expect(thin.count == 100)
        #expect(thin.first == [0, 0])
        #expect(thin.last == [999, 0])
        #expect(RunRecord.thin([[1, 1]], limit: 100).count == 1)
    }

    @Test func roundTripsThroughTheApiCoders() throws {
        let run = RunRecord.make(plan: RunPlan(), segments: [RunSegment(kind: .run, meters: 100, seconds: 30)], route: [[1, 2]], startedAt: Date(), elapsed: 30)
        let json = try #require(try JSONSerialization.jsonObject(with: API.encoder.encode(run)) as? [String: Any])
        #expect(json["duration_s"] as? Int == 30)
        #expect(json["plan_run_m"] != nil)
        #expect(try API.decoder.decode(RunRecord.self, from: API.encoder.encode(run)) == run)
        #expect(json["source"] as? String == "gps")
    }

    @Test func oldRowsWithoutASourceAreGps() throws {
        let row = #"{"id":"a","date":"2026-11-01","started_at":"2026-11-01T07:00:00Z","duration_s":60,"distance_m":100,"run_m":100,"walk_m":0,"run_s":60,"rounds_done":0}"#
        let run = try API.decoder.decode(RunRecord.self, from: Data(row.utf8))
        #expect(run.source == nil)
        #expect(!run.isTreadmill)
    }
}

struct TreadmillTests {
    let mile = RunPlan.metersPerMile

    @Test func buildsARunFromTheTreadmillDisplay() throws {
        var entry = TreadmillEntry(miles: "3,1", minutes: "28", seconds: "30")
        #expect(entry.problem == nil)
        let finished = Date(timeIntervalSince1970: 1_800_000_000)
        let run = try #require(entry.record(finishedAt: finished, pain: 1, notes: nil))
        #expect(run.isTreadmill)
        #expect(run.durationS == 1710)
        #expect(abs(run.distanceM - 3.1 * mile) < 0.001)
        #expect(run.runS == 1710)
        #expect(run.walkM == 0)
        #expect(run.started == finished.addingTimeInterval(-1710))
        #expect(run.route == [])
        #expect(run.planRounds == nil)

        // Walking comes out of the run distance and time, so run pace stays honest.
        entry.walkMiles = "0.5"
        entry.walkMinutes = "8.5"
        let mixed = try #require(entry.record(finishedAt: finished, pain: nil, notes: nil))
        #expect(abs(mixed.runM - 2.6 * mile) < 0.001)
        #expect(mixed.runS == 1710 - 510)
    }

    @Test func refusesEntriesThatDontAddUp() {
        #expect(TreadmillEntry(minutes: "20").problem != nil)
        #expect(TreadmillEntry(miles: "2").problem != nil)
        #expect(TreadmillEntry(miles: "abc", minutes: "20").problem != nil)
        #expect(TreadmillEntry(miles: "2", minutes: "20", walkMiles: "3").problem != nil)
        #expect(TreadmillEntry(miles: "2", minutes: "20", walkMiles: "1", walkMinutes: "25").problem != nil)
        #expect(TreadmillEntry(miles: "2", minutes: "0", seconds: "0").problem != nil)
        #expect(TreadmillEntry(miles: "2", minutes: "20", walkMiles: "2", walkMinutes: "20").problem == nil)
        // Walk distance and walk time come as a pair, or walking still drags down run pace.
        #expect(TreadmillEntry(miles: "2", minutes: "20", walkMiles: "0.5").problem != nil)
        #expect(TreadmillEntry(miles: "2", minutes: "20", walkMinutes: "5").problem != nil)
        // Huge numbers are refused instead of crashing when turned into seconds.
        let huge = TreadmillEntry(miles: "2", minutes: "999999999999999999")
        #expect(huge.durationS == nil)
        #expect(huge.problem != nil)
        #expect(huge.record(finishedAt: Date(), pain: nil, notes: nil) == nil)
        let hugeWalk = TreadmillEntry(miles: "2", minutes: "20", walkMiles: "1", walkMinutes: "1e300")
        #expect(hugeWalk.walkS == nil)
        #expect(hugeWalk.problem != nil)
    }
}

@MainActor
struct RunStoreTests {
    /// Demo mode routes API calls to the in-memory backend, so this exercises save, list and delete end to end.
    @Test func savesListsAndDeletesInDemoMode() async throws {
        UserDefaults.standard.set(true, forKey: "demoMode")
        defer { UserDefaults.standard.removeObject(forKey: "demoMode") }
        let url = FileManager.default.temporaryDirectory.appending(path: "pending-\(UUID().uuidString).json")
        let store = RunStore(pendingURL: url)
        var run = RunRecord.make(plan: RunPlan(), segments: [RunSegment(kind: .run, meters: 482, seconds: 180)], route: [[1, 2], [3, 4]], startedAt: Date(), elapsed: 180)
        run.pain = 2
        await store.save(run)
        #expect(store.pending.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        await store.load()
        let saved = try #require(store.all.first { $0.id == run.id })
        #expect(saved.pain == 2)
        #expect(saved.route == nil)  // list queries leave the route out
        #expect(await store.route(for: saved) == [[1, 2], [3, 4]])
        await store.delete(saved)
        #expect(!store.all.contains { $0.id == run.id })

        // Treadmill runs save and list the same way, keep their label, and have no route to fetch.
        let treadmill = try #require(TreadmillEntry(miles: "2", minutes: "20").record(finishedAt: Date(), pain: 0, notes: "Incline 1%"))
        await store.save(treadmill)
        await store.load()
        let listed = try #require(store.all.first { $0.id == treadmill.id })
        #expect(listed.isTreadmill)
        #expect(listed.notes == "Incline 1%")
        #expect(await store.route(for: listed) == [])
        await store.delete(listed)
    }
}
