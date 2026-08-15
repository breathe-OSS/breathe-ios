// SPDX-License-Identifier: MIT
/*
 * WeatherHistory.swift - Join weather-history buckets with PM samples for filters and impact cards
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 Suvesh Moza <hellosuvesh@gmail.com>
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

let weatherFilterLabels: [(condition: String, label: String)] = [
    ("rain", "Rain"),
    ("snow", "Snow"),
    ("fog", "Fog"),
    ("cloudy", "Cloudy"),
    ("clear", "Clear"),
]

func weatherConditionSymbol(_ condition: String) -> String {
    switch condition.lowercased() {
    case "clear": return "sun.max.fill"
    case "rain": return "cloud.rain.fill"
    case "thunderstorm": return "cloud.bolt.rain.fill"
    case "fog", "smog": return "cloud.fog.fill"
    case "all": return "line.3.horizontal.decrease"
    default: return "cloud.fill"
    }
}

struct WeatherPm25Group: Identifiable {
    var id: String { condition }
    let condition: String
    let label: String
    let avg: Double
    let hours: Int
    let diffPct: Int
}

private func conditionForTs(
    ts: Int,
    interval: Int,
    lookup: [Int: WeatherHistoryPoint]
) -> String? {
    let safeInterval = max(interval, 1)
    let bucket = (ts / safeInterval) * safeInterval
    return lookup[bucket]?.condition
}

func matchesWeatherFilter(condition: String?, filter: String) -> Bool {
    if filter == "all" { return true }
    guard let condition else { return false }
    if filter == "rain" { return condition == "rain" || condition == "thunderstorm" }
    return condition == filter
}

func filterHistoryByWeather(
    data: [HistoricalDataPoint],
    weather: WeatherHistory?,
    filter: String
) -> [HistoricalDataPoint] {
    if filter == "all" { return data }
    guard let weather, !weather.points.isEmpty else { return [] }
    let lookup = Dictionary(weather.points.map { ($0.ts, $0) }, uniquingKeysWith: { _, last in last })
    let interval = weather.interval
    return data.filter { matchesWeatherFilter(condition: conditionForTs(ts: $0.ts, interval: interval, lookup: lookup), filter: filter) }
}

func weatherPm25Groups(
    data: [HistoricalDataPoint],
    weather: WeatherHistory?
) -> [String: (sum: Double, count: Int)] {
    guard let weather, !weather.points.isEmpty else { return [:] }
    let lookup = Dictionary(weather.points.map { ($0.ts, $0) }, uniquingKeysWith: { _, last in last })
    let interval = weather.interval
    var groups: [String: (sum: Double, count: Int)] = [:]
    for point in data {
        guard let pm25 = point.pm25 else { continue }
        guard var condition = conditionForTs(ts: point.ts, interval: interval, lookup: lookup) else { continue }
        if condition == "thunderstorm" { condition = "rain" }
        let current = groups[condition] ?? (sum: 0, count: 0)
        groups[condition] = (sum: current.sum + pm25, count: current.count + 1)
    }
    return groups
}

func weatherImpactCards(
    data: [HistoricalDataPoint],
    weather: WeatherHistory?
) -> [WeatherPm25Group] {
    let groups = weatherPm25Groups(data: data, weather: weather)
    if groups.isEmpty { return [] }
    let totalSum = groups.values.reduce(0) { $0 + $1.sum }
    let totalCount = groups.values.reduce(0) { $0 + $1.count }
    if totalCount == 0 { return [] }
    let overallAvg = totalSum / Double(totalCount)
    let interval = weather?.interval ?? 3600

    let cards = weatherFilterLabels.compactMap { condition, label -> WeatherPm25Group? in
        guard let group = groups[condition], group.count >= 3 else { return nil }
        let avg = group.sum / Double(group.count)
        let hours = Int((Double(group.count * interval) / 3600.0).rounded())
        let diffPct: Int
        if overallAvg == 0 {
            diffPct = 0
        } else {
            diffPct = Int((((avg - overallAvg) / overallAvg) * 100).rounded())
        }
        return WeatherPm25Group(
            condition: condition,
            label: label,
            avg: avg,
            hours: hours,
            diffPct: diffPct
        )
    }
    return cards.count >= 2 ? cards : []
}
