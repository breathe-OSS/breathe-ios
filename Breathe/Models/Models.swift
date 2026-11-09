// SPDX-License-Identifier: MIT
/*
 * Models.swift
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 sidharthify <wednisegit@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

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
    let averages24h: [String: Double]?
    let trends: Trends?
    let warning: String?
    let source: String?
    let nodes: [String: NodeReading]?
    let weather: WeatherInfo?

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
        case averages24h     = "averages_24h"
        case nodes
        case history, trends, warning, source, weather
    }
}

struct WeatherInfo: Codable {
    var condition: String = ""
    var weatherCode: Int?
    var precipitation: Double?
    var season: String = ""
    var text: String = ""

    enum CodingKeys: String, CodingKey {
        case condition, precipitation, season, text
        case weatherCode = "weather_code"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        condition = try container.decodeIfPresent(String.self, forKey: .condition) ?? ""
        weatherCode = try container.decodeIfPresent(Int.self, forKey: .weatherCode)
        precipitation = try container.decodeIfPresent(Double.self, forKey: .precipitation)
        season = try container.decodeIfPresent(String.self, forKey: .season) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
    }
}

struct WeatherHistoryPoint: Codable {
    let ts: Int
    var condition: String = ""
    var precipitation: Double?

    enum CodingKeys: String, CodingKey {
        case ts, condition, precipitation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ts = try container.decode(Int.self, forKey: .ts)
        condition = try container.decodeIfPresent(String.self, forKey: .condition) ?? ""
        precipitation = try container.decodeIfPresent(Double.self, forKey: .precipitation)
    }
}

struct WeatherHistory: Codable {
    var interval: Int = 3600
    var anchor: Int? = nil
    var points: [WeatherHistoryPoint] = []
    var zoneId: String?

    enum CodingKeys: String, CodingKey {
        case interval, anchor, points
        case zoneId = "zone_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 3600
        points = try container.decodeIfPresent([WeatherHistoryPoint].self, forKey: .points) ?? []
        zoneId = try container.decodeIfPresent(String.self, forKey: .zoneId)
    }
}

struct NodeHistoryPoint: Codable {
    let ts: Int
    let aqi: Int
    let usAqi: Int?
    let pm25: Double?
    let pm10: Double?

    enum CodingKeys: String, CodingKey {
        case ts, aqi
        case usAqi = "us_aqi"
        case pm25  = "pm2_5"
        case pm10  = "pm10"
    }
}

struct NodeReading: Codable {
    let pm25: Double?
    let pm10: Double?
    let temp: Double?
    let humidity: Double?
    let aqi: Int?
    let usAqi: Int?
    let timestamp: Int?
    let history: [NodeHistoryPoint]?

    enum CodingKeys: String, CodingKey {
        case temp, humidity, aqi, timestamp, history
        case usAqi = "us_aqi"
        case pm25  = "pm2_5"
        case pm10  = "pm10"
    }
}

struct SensorInfoResponse: Codable {
    let sensors: [SensorInfo]
}

struct SensorInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let zone: String
    let provider: String
    let model: String
    let locationId: Int
    let installationDate: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case name, zone, provider, model, latitude, longitude
        case locationId = "location_id"
        case installationDate = "installation_date"
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

// MARK: - Extended History

struct HistoricalDataPoint: Codable, Identifiable {
    var id: Int { ts }

    let zoneId: String?
    let ts: Int
    let pm25: Double?
    let pm10: Double?

    enum CodingKeys: String, CodingKey {
        case zoneId = "zone_id"
        case ts
        case pm25 = "pm2_5"
        case pm10 = "pm10"
    }
}

struct HistoricalStats: Codable {
    let maxPm25: Double?
    let minPm25: Double?
    let avgPm25: Double?
    let maxPm10: Double?
    let minPm10: Double?
    let avgPm10: Double?

    enum CodingKeys: String, CodingKey {
        case maxPm25 = "max_pm2_5"
        case minPm25 = "min_pm2_5"
        case avgPm25 = "avg_pm2_5"
        case maxPm10 = "max_pm10"
        case minPm10 = "min_pm10"
        case avgPm10 = "avg_pm10"
    }
}

struct HistoricalDataResponse: Codable {
    let data: [HistoricalDataPoint]
    let stats: HistoricalStats?
}

enum HistoryPeriodMode: String, CaseIterable, Identifiable {
    case month = "Month"
    case week = "Week"
    case days = "Days"

    var id: String { rawValue }
}

struct HistoryPeriod: Equatable {
    let start: Date
    let end: Date

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    static func containing(mode: HistoryPeriodMode, date: Date) -> HistoryPeriod {
        let calendar = Self.calendar
        let day = calendar.startOfDay(for: date)

        switch mode {
        case .month:
            let start = calendar.dateInterval(of: .month, for: day)?.start ?? day
            let next = calendar.date(byAdding: .month, value: 1, to: start) ?? day
            let end = calendar.date(byAdding: .day, value: -1, to: next) ?? day
            return HistoryPeriod(start: start, end: end)
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? day
            return HistoryPeriod(start: start, end: end)
        case .days:
            return HistoryPeriod(start: day, end: day)
        }
    }

    static func span(from first: Date, to second: Date) -> HistoryPeriod {
        let calendar = Self.calendar
        let a = calendar.startOfDay(for: first)
        let b = calendar.startOfDay(for: second)
        return a <= b ? HistoryPeriod(start: a, end: b) : HistoryPeriod(start: b, end: a)
    }

    private var dayCount: Int {
        let days = Self.calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }

    func shifted(mode: HistoryPeriodMode, by direction: Int) -> HistoryPeriod {
        let calendar = Self.calendar

        if mode == .month {
            let target = calendar.date(byAdding: .month, value: direction, to: start) ?? start
            return Self.containing(mode: .month, date: target)
        }

        let days = direction * dayCount
        let newStart = calendar.date(byAdding: .day, value: days, to: start) ?? start
        let newEnd = calendar.date(byAdding: .day, value: days, to: end) ?? end
        return HistoryPeriod(start: newStart, end: newEnd)
    }

    private static func calendarString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    var token: String {
        "\(Self.calendarString(start))_\(Self.calendarString(end))"
    }

    var interval: String {
        if dayCount <= 14 {
            return "1h"
        }
        if dayCount <= 62 {
            return "4h"
        }
        return "1d"
    }

    func label(mode: HistoryPeriodMode) -> String {
        if mode == .month {
            return start.formatted(.dateTime.month(.wide).year())
        }

        let style = Date.FormatStyle().day().month(.abbreviated).year()
        if start == end {
            return start.formatted(style)
        }
        return "\(start.formatted(style)) to \(end.formatted(style))"
    }
}

struct HistoryState {
    var isLoading = false
    var data: [HistoricalDataPoint] = []
    var stats: HistoricalStats? = nil
    var selectedRange = "1w"
    var selectedSensor = "zone"
    var showPm25 = true
    var showPm10 = true
    var customRange = "14d"
    var customInterval = "1h"
    var showCustomInputs = false
    var error: String? = nil
    var weatherHistory: WeatherHistory? = nil
    var weatherFilter = "all"
    var periodActive = false
    var periodMode: HistoryPeriodMode = .month
    var period: HistoryPeriod? = nil
}

