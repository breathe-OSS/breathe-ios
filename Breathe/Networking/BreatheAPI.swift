import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .httpError(let code):  return "Server returned \(code)"
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .networkError(let e):  return e.localizedDescription
        }
    }
}

final class BreatheAPI: @unchecked Sendable {
    static let shared = BreatheAPI()

    private let baseURL = "https://api.breatheoss.app"
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    private init() {}

    func getZones() async throws -> [Zone] {
        let response: ZonesResponse = try await get(path: "/zones")
        return response.zones
    }

    func getZoneAqi(zoneId: String) async throws -> AqiResponse {
        return try await get(path: "/aqi/zone/\(zoneId)")
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
