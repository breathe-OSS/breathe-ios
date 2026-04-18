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
        case nodes
        case history, trends, warning, source
    }
}

struct NodeReading: Codable {
    let pm25: Double?
    let pm10: Double?
    let temp: Double?
    let humidity: Double?
    let aqi: Int?
    let timestamp: Int?

    enum CodingKeys: String, CodingKey {
        case temp, humidity, aqi, timestamp
        case pm25 = "pm2.5"
        case pm10 = "pm10"
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
