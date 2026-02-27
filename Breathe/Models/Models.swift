import Foundation

struct ZonesResponse: Codable {
    let zones: [Zone]
}

struct Zone: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String?
    let lat: Double?
    let lon: Double?
}

struct AqiResponse: Codable, Identifiable {
    var id: String { zoneId }

    let zoneId: String
    let zoneName: String
    let nAqi: Int
    let usAqi: Int?
    let mainPollutant: String
    let usMainPollutant: String?
    let aqiBreakdown: [String: Int]?
    let concentrations: [String: Double]?
    let timestampUnix: Double?
    let lastUpdateStr: String?
    let history: [HistoryPoint]?
    let trends: Trends?
    let warning: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case zoneId          = "zone_id"
        case zoneName        = "zone_name"
        case nAqi            = "aqi"
        case usAqi           = "us_aqi"
        case mainPollutant   = "main_pollutant"
        case usMainPollutant = "us_main_pollutant"
        case aqiBreakdown    = "aqi_breakdown"
        case concentrations  = "concentrations_us_units"
        case timestampUnix   = "timestamp_unix"
        case lastUpdateStr   = "last_update"
        case history, trends, warning, source
    }
}

struct HistoryPoint: Codable {
    let ts: Int
    let aqi: Int
    let usAqi: Int?

    enum CodingKeys: String, CodingKey {
        case ts, aqi
        case usAqi = "us_aqi"
    }
}

struct Trends: Codable {
    let change1h: Int?
    let change24h: Int?

    enum CodingKeys: String, CodingKey {
        case change1h  = "change_1h"
        case change24h = "change_24h"
    }
}
