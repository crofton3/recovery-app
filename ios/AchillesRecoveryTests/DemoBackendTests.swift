import Foundation
import Testing
@testable import AchillesRecovery

/// The demo backend stands in for PostgREST, so its filtering has to match what the app's queries expect.
/// Each test uses its own table so tests can run in parallel against the shared instance.
struct DemoBackendTests {
    let backend = DemoBackend.shared
    let table = "test_\(UUID().uuidString.prefix(8))"

    private func insert(_ rows: [[String: Any]], query: [String: String] = [:]) throws {
        _ = backend.handle(method: "POST", table: table, query: query, body: try JSONSerialization.data(withJSONObject: rows), prefer: nil)
    }

    private func get(_ query: [String: String] = [:]) throws -> [[String: Any]] {
        let data = backend.handle(method: "GET", table: table, query: query, body: nil, prefer: nil)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    @Test func insertAssignsIdsAndReturnsRepresentation() throws {
        let body = try JSONSerialization.data(withJSONObject: ["name": "a"])
        let data = backend.handle(method: "POST", table: table, query: [:], body: body, prefer: "return=representation")
        let rows = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(rows.count == 1)
        #expect((rows[0]["id"] as? String)?.isEmpty == false)
        #expect(rows[0]["created_at"] is String)
    }

    @Test func filtersByEqualityGteAndNull() throws {
        try insert([
            ["date": "2026-01-01", "done": true, "n": 1],
            ["date": "2026-01-05", "done": false, "n": 2, "completed_at": "x"],
            ["date": "2026-01-09", "done": true, "n": 3],
        ])
        #expect(try get(["done": "eq.true"]).count == 2)
        #expect(try get(["date": "gte.2026-01-05"]).count == 2)
        #expect(try get(["completed_at": "is.null"]).count == 2)
        #expect(try get(["completed_at": "not.is.null"]).count == 1)
        #expect(try get(["n": "eq.2"]).first?["date"] as? String == "2026-01-05")
    }

    @Test func ordersLimitsAndSelects() throws {
        try insert([["n": 2, "k": "b"], ["n": 10, "k": "c"], ["n": 1, "k": "a"]])
        #expect(try get(["order": "n"]).compactMap { $0["n"] as? Int } == [1, 2, 10])
        #expect(try get(["order": "n.desc", "limit": "2"]).compactMap { $0["n"] as? Int } == [10, 2])
        #expect(try get(["select": "k"]).allSatisfy { $0.keys.sorted() == ["k"] })
    }

    /// Regression: JSON 0 and 1 used to compare as false and true, so `set_no=eq.1` missed rows the app inserted.
    @Test func numbersFromJsonAreNotBooleans() throws {
        try insert([["set_no": 1, "done": true], ["set_no": 2, "done": false], ["set_no": 0, "done": true]])
        #expect(try get(["set_no": "eq.1"]).count == 1)
        #expect(try get(["set_no": "eq.0"]).count == 1)
        #expect(try get(["done": "eq.true"]).count == 2)
    }

    @Test func upsertMergesOnConflict() throws {
        try insert([["date": "2026-02-01", "water_oz": 10]])
        try insert([["date": "2026-02-01", "water_oz": 40]], query: ["on_conflict": "date"])
        let rows = try get()
        #expect(rows.count == 1)
        #expect(rows.first?["water_oz"] as? Int == 40)
    }

    @Test func patchAndDeleteMatchById() throws {
        try insert([["id": "keep", "v": 1], ["id": "edit", "v": 1]])
        _ = backend.handle(method: "PATCH", table: table, query: ["id": "eq.edit"], body: try JSONSerialization.data(withJSONObject: ["v": 2]), prefer: nil)
        #expect(try get(["id": "eq.edit"]).first?["v"] as? Int == 2)
        #expect(try get(["id": "eq.keep"]).first?["v"] as? Int == 1)

        _ = backend.handle(method: "DELETE", table: table, query: ["id": "eq.edit"], body: nil, prefer: nil)
        #expect(try get().compactMap { $0["id"] as? String } == ["keep"])
    }
}
