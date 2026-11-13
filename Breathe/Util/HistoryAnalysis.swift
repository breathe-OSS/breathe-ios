// SPDX-License-Identifier: MIT
/*
 * HistoryAnalysis.swift - Bucketing, summaries and sensor comparison for extended history
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

let compareMinOverlap = 24
let historyMetrics = "pm2.5,pm10,temp,humidity,us_aqi,pm2.5_raw,pm10_raw,temp_raw,humidity_raw,us_aqi_raw"
let usAqiBands: [Double] = [0, 50, 100, 150, 200, 300, 500]
let pm25Bands: [Double] = [0, 9, 35.4, 55.4, 125.4, 225.4, 325.4]
let pm10Bands: [Double] = [0, 54, 154, 254, 354, 424, 604]
let usCategorySamples = [25, 75, 125, 175, 250, 400]

enum SeriesHue {
    case primary
    case secondary
    case raw
}

struct HistorySeries: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
    let raw: Bool
    let hue: SeriesHue
}

struct BucketRow: Identifiable {
    var id: Int { ts }
    let ts: Int
    let values: [String: Double]
}

struct SeriesStats {
    let avg: Double?
    let maxValue: Double?
    let maxTs: Int?
    let minValue: Double?
    let count: Int
}

struct PairStats {
    let n: Int
    let r: Double?
    let ratio: Double?
    let gap: Double?
}

enum VerdictTone {
    case good
    case fair
    case poor
    case none
}

struct Verdict {
    let label: String
    let tone: VerdictTone
}

extension HistoryMetric {
    var bands: [Double]? {
        switch self {
        case .aqi: return usAqiBands
        case .pm25: return pm25Bands
        case .pm10: return pm10Bands
        default: return nil
        }
    }
}

func activeSeries(metric: HistoryMetric, mode: HistoryMode) -> [HistorySeries] {
    var out: [HistorySeries] = []
    for (index, key) in metric.keys.enumerated() {
        let hue: SeriesHue = index == 0 ? .primary : .secondary
        let name = metric.names[index]
        if mode != .raw {
            out.append(HistorySeries(key: key, label: name, raw: false, hue: hue))
        }
        if mode != .cal {
            let rawHue: SeriesHue = metric.keys.count == 1 && mode == .both ? .raw : hue
            out.append(HistorySeries(key: "\(key)_raw", label: "\(name) raw", raw: true, hue: rawHue))
        }
    }
    return out
}

func compareKey(metric: HistoryMetric, mode: HistoryMode) -> String {
    let base = metric.keys[0]
    return mode == .raw ? "\(base)_raw" : base
}

func compareLabel(metric: HistoryMetric, mode: HistoryMode) -> String {
    let name = metric.names[0]
    return mode == .raw ? "\(name) raw" : name
}

func intervalSeconds(_ token: String) -> Int {
    let trimmed = token.trimmingCharacters(in: .whitespaces).lowercased()
    let digits = trimmed.prefix { $0.isNumber }
    guard let n = Int(digits) else {
        return 3600
    }
    let unit = trimmed.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
    switch unit {
    case "m": return n * 60
    case "h": return n * 3600
    case "d": return n * 86400
    case "w": return n * 604800
    case "mo": return n * 2592000
    default: return 3600
    }
}

func displayBucket(_ points: [HistoricalDataPoint], interval: String) -> Int {
    let base = intervalSeconds(interval)
    guard points.count >= 2, let first = points.first, let last = points.last else {
        return base
    }
    let span = last.ts - first.ts
    if span > 62 * 86400 {
        return max(base, 86400)
    }
    if span > 14 * 86400 {
        return max(base, 4 * 3600)
    }
    return base
}

func aggregate(_ points: [HistoricalDataPoint], bucket: Int, interval: String, keys: [String]) -> [BucketRow] {
    if bucket <= intervalSeconds(interval) {
        return points.map { point in
            var values: [String: Double] = [:]
            for key in keys {
                if let v = point.value(key) {
                    values[key] = v
                }
            }
            return BucketRow(ts: point.ts, values: values)
        }
    }
    let offset = TimeZone.current.secondsFromGMT()
    var out: [BucketRow] = []
    var currentTs: Int? = nil
    var sums: [String: Double] = [:]
    var counts: [String: Int] = [:]
    func flush() {
        guard let ts = currentTs else {
            return
        }
        var values: [String: Double] = [:]
        for key in keys {
            if let count = counts[key], count > 0, let sum = sums[key] {
                values[key] = sum / Double(count)
            }
        }
        out.append(BucketRow(ts: ts, values: values))
        sums = [:]
        counts = [:]
    }
    for point in points {
        let shifted = point.ts + offset
        let floored = Int((Double(shifted) / Double(bucket)).rounded(.down)) * bucket
        let start = floored - offset
        if currentTs != start {
            flush()
            currentTs = start
        }
        for key in keys {
            if let v = point.value(key) {
                sums[key, default: 0] += v
                counts[key, default: 0] += 1
            }
        }
    }
    flush()
    return out
}

func seriesStats(_ points: [HistoricalDataPoint], key: String) -> SeriesStats {
    var sum = 0.0
    var count = 0
    var maxValue: Double? = nil
    var maxTs: Int? = nil
    var minValue: Double? = nil
    for point in points {
        guard let v = point.value(key) else {
            continue
        }
        sum += v
        count += 1
        if maxValue == nil || v > maxValue! {
            maxValue = v
            maxTs = point.ts
        }
        if minValue == nil || v < minValue! {
            minValue = v
        }
    }
    return SeriesStats(avg: count > 0 ? sum / Double(count) : nil, maxValue: maxValue, maxTs: maxTs, minValue: minValue, count: count)
}

func bandSample(_ value: Double, bands: [Double]) -> Int {
    guard let found = bands.firstIndex(where: { value < $0 }) else {
        return usCategorySamples[5]
    }
    return usCategorySamples[min(max(found - 1, 0), 5)]
}

func seriesByTs(_ points: [HistoricalDataPoint], key: String) -> [Int: Double] {
    var out: [Int: Double] = [:]
    for point in points {
        if let v = point.value(key) {
            out[point.ts] = v
        }
    }
    return out
}

func pairStats(_ a: [Int: Double], _ b: [Int: Double]) -> PairStats {
    var xs: [Double] = []
    var ys: [Double] = []
    for (ts, v) in a {
        if let w = b[ts] {
            xs.append(v)
            ys.append(w)
        }
    }
    let n = xs.count
    guard n >= 2 else {
        return PairStats(n: n, r: nil, ratio: nil, gap: nil)
    }
    let mx = xs.reduce(0, +) / Double(n)
    let my = ys.reduce(0, +) / Double(n)
    var sxy = 0.0
    var sxx = 0.0
    var syy = 0.0
    var gap = 0.0
    var ratios: [Double] = []
    for i in 0..<n {
        sxy += (xs[i] - mx) * (ys[i] - my)
        sxx += (xs[i] - mx) * (xs[i] - mx)
        syy += (ys[i] - my) * (ys[i] - my)
        gap += abs(ys[i] - xs[i])
        if xs[i] > 0 {
            ratios.append(ys[i] / xs[i])
        }
    }
    ratios.sort()
    let ratio = ratios.isEmpty ? nil : ratios[ratios.count / 2]
    let r = sxx > 0 && syy > 0 ? sxy / (sxx * syy).squareRoot() : nil
    return PairStats(n: n, r: r, ratio: ratio, gap: gap / Double(n))
}

func verdictFor(_ stats: PairStats, metric: HistoryMetric) -> Verdict {
    guard stats.n >= compareMinOverlap, let r = stats.r else {
        return Verdict(label: "Not enough overlap", tone: .none)
    }
    let levelMatches: Bool
    if metric == .temp || metric == .humidity {
        let limit = metric == .temp ? 2.0 : 8.0
        levelMatches = (stats.gap ?? .infinity) <= limit
    } else {
        levelMatches = abs((stats.ratio ?? .infinity) - 1) <= 0.15
    }
    if r >= 0.9 && levelMatches {
        return Verdict(label: "Very consistent", tone: .good)
    }
    if r >= 0.9 {
        return Verdict(label: "Same pattern, different level", tone: .fair)
    }
    if r >= 0.75 {
        return Verdict(label: "Mostly consistent", tone: .fair)
    }
    if r >= 0.5 {
        return Verdict(label: "Loosely related", tone: .poor)
    }
    return Verdict(label: "Inconsistent", tone: .poor)
}

func formatValue(_ value: Double?, decimals: Int) -> String {
    guard let value, !value.isNaN else {
        return "--"
    }
    if decimals == 0 {
        return String(Int(value.rounded()))
    }
    return String(format: "%.\(decimals)f", value)
}

func unitSuffix(_ unit: String) -> String {
    unit == "US AQI" ? "" : " \(unit)"
}

func rawNote(rows: [HistoricalDataPoint], metric: HistoryMetric, interval: String) -> String? {
    let keys = metric.keys.map { "\($0)_raw" }
    guard let first = rows.first(where: { row in keys.contains { row.value($0) != nil } }) else {
        return "There are no raw readings stored for this range yet. Breathe only started keeping them recently."
    }
    if let start = rows.first, first.ts - start.ts > 2 * intervalSeconds(interval) {
        let day = Date(timeIntervalSince1970: TimeInterval(first.ts)).formatted(.dateTime.day().month(.abbreviated).year())
        return "Raw readings for this sensor start on \(day). Earlier parts of the range are blank in raw."
    }
    return nil
}
