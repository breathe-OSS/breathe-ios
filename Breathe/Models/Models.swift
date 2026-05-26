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
        case history, trends, warning, source
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

    enum CodingKeys: String, CodingKey {
        case name, zone, provider, model
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
}

