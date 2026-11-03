import Foundation

/// Minimal Supabase PostgREST client (no third-party dependency).
enum API {
    struct Failure: LocalizedError {
        let status: Int
        let body: String
        var errorDescription: String? { "Supabase \(status): \(body)" }
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    @discardableResult
    static func send(_ method: String, _ table: String, query: [String: String] = [:], body: Data? = nil, prefer: String? = nil) async throws -> Data {
        var comps = URLComponents(string: Secrets.supabaseURL + "/rest/v1/" + table)!
        if !query.isEmpty { comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer " + Secrets.supabaseAnonKey, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Failure(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    static func get<T: Decodable>(_ table: String, query: [String: String] = [:], as type: T.Type = T.self) async throws -> [T] {
        let data = try await send("GET", table, query: query)
        return try decoder.decode([T].self, from: data)
    }

    static func insert<T: Encodable, R: Decodable>(_ table: String, _ value: T, as type: R.Type = R.self) async throws -> R {
        let data = try await send("POST", table, body: encoder.encode(value), prefer: "return=representation")
        guard let first = try decoder.decode([R].self, from: data).first else {
            throw Failure(status: 0, body: "Insert returned no row")
        }
        return first
    }

    static func patch<T: Encodable>(_ table: String, id: String, _ value: T) async throws {
        try await send("PATCH", table, query: ["id": "eq.\(id)"], body: encoder.encode(value), prefer: "return=minimal")
    }

    static func delete(_ table: String, id: String) async throws {
        try await send("DELETE", table, query: ["id": "eq.\(id)"], prefer: "return=minimal")
    }

    static func upsert<T: Encodable>(_ table: String, _ value: T, onConflict: String) async throws {
        try await send("POST", table, query: ["on_conflict": onConflict], body: encoder.encode(value),
                       prefer: "resolution=merge-duplicates,return=minimal")
    }
}
