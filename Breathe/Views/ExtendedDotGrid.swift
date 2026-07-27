// SPDX-License-Identifier: MIT
/*
 * ExtendedDotGrid.swift
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

import SwiftUI

private struct GridDay: Identifiable {
    let id: Int
    let dayStart: Date
    var pm25: [Double?]
    var pm10: [Double?]

    var avgPm25: Double? {
        let values = pm25.compactMap { $0 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var avgPm10: Double? {
        let values = pm10.compactMap { $0 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

private struct GridModel {
    let days: [GridDay]
    let hourly: Bool
    let gridStart: Date
    let numWeeks: Int
    let dayMap: [Int: GridDay]
}

struct ExtendedDotGrid: View {
    let data: [HistoricalDataPoint]
    let showPm25: Bool
    let showPm10: Bool

    @State private var selectedID: String? = nil
    @State private var selectedLabel: String? = nil

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private var use25: Bool { showPm25 || (!showPm25 && !showPm10) }
    private var use10: Bool { showPm10 || (!showPm25 && !showPm10) }

    var body: some View {
        let model = prepare()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.hourly ? "By Day and Hour" : "Daily Average")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(selectedLabel ?? "Tap a cell for details")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(selectedLabel == nil ? .regular : .semibold)
                    .foregroundStyle(selectedLabel == nil ? .secondary : .primary)
                    .lineLimit(1)
            }

            if model.days.isEmpty {
                Text("No data available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else if model.hourly {
                punchCard(model)
            } else {
                calendarGrid(model)
            }

            legend
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Punch Card (day x hour)

    @ViewBuilder
    private func punchCard(_ model: GridModel) -> some View {
        VStack(spacing: 3) {
            ForEach(model.days) { day in
                HStack(spacing: 3) {
                    Text(Self.weekdayFormatter.string(from: day.dayStart))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)

                    ForEach(0..<24, id: \.self) { hour in
                        cell(
                            id: "\(day.id)-\(hour)",
                            aqi: cellAqi(day.pm25[hour], day.pm10[hour]),
                            label: "\(cellValues(day.pm25[hour], day.pm10[hour]))  ·  \(Self.weekdayFormatter.string(from: day.dayStart)) \(String(format: "%02d:00", hour))"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 14)
                    }
                }
            }

            HStack(spacing: 3) {
                Color.clear.frame(width: 32, height: 1)
                ForEach(0..<24, id: \.self) { hour in
                    Text([0, 6, 12, 18].contains(hour) ? "\(hour)" : "")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Calendar (weekday x week)

    @ViewBuilder
    private func calendarGrid(_ model: GridModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 3) {
                    Color.clear.frame(width: 24, height: 12)
                    ForEach(0..<7, id: \.self) { weekday in
                        Text([1, 3, 5].contains(weekday) ? Self.weekdayFormatter.string(from: date(model.gridStart, addingDays: weekday)) : "")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 14, alignment: .leading)
                    }
                }

                ForEach(Array(0..<model.numWeeks), id: \.self) { week in
                    VStack(spacing: 3) {
                        Text(monthLabel(model, week: week))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 12, alignment: .leading)

                        ForEach(0..<7, id: \.self) { weekday in
                            calendarCell(model, week: week, weekday: weekday)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calendarCell(_ model: GridModel, week: Int, weekday: Int) -> some View {
        let cellDate = date(model.gridStart, addingDays: week * 7 + weekday)
        let key = Int(Calendar.current.startOfDay(for: cellDate).timeIntervalSince1970)
        let day = model.dayMap[key]
        let aqi = day.flatMap { cellAqi($0.avgPm25, $0.avgPm10) }
        let label = day.map { "\(cellValues($0.avgPm25, $0.avgPm10))  ·  \(Self.dayLabelFormatter.string(from: $0.dayStart))" } ?? ""

        cell(id: "cal-\(key)", aqi: aqi, label: label)
            .frame(width: 14, height: 14)
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(id: String, aqi: Int?, label: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(aqi.map { usAqiColor($0) } ?? Color(.tertiarySystemFill))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                    .opacity(selectedID == id ? 1 : 0)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard aqi != nil else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    if selectedID == id {
                        selectedID = nil
                        selectedLabel = nil
                    } else {
                        selectedID = id
                        selectedLabel = label
                    }
                }
            }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Good")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
            ForEach([25, 75, 125, 175, 250, 400], id: \.self) { rep in
                RoundedRectangle(cornerRadius: 2)
                    .fill(usAqiColor(rep))
                    .frame(width: 16, height: 6)
            }
            Text("Hazardous")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Model

    private func prepare() -> GridModel {
        let calendar = Calendar.current
        var map: [Int: GridDay] = [:]
        var counts25: [Int: [Int]] = [:]
        var counts10: [Int: [Int]] = [:]

        for point in data {
            let date = Date(timeIntervalSince1970: TimeInterval(point.ts))
            let hour = calendar.component(.hour, from: date)
            let dayStart = calendar.startOfDay(for: date)
            let key = Int(dayStart.timeIntervalSince1970)

            if map[key] == nil {
                map[key] = GridDay(id: key, dayStart: dayStart, pm25: Array(repeating: nil, count: 24), pm10: Array(repeating: nil, count: 24))
                counts25[key] = Array(repeating: 0, count: 24)
                counts10[key] = Array(repeating: 0, count: 24)
            }

            if let value = point.pm25 {
                let count = counts25[key]![hour]
                let existing = map[key]!.pm25[hour]
                map[key]!.pm25[hour] = existing.map { ($0 * Double(count) + value) / Double(count + 1) } ?? value
                counts25[key]![hour] = count + 1
            }
            if let value = point.pm10 {
                let count = counts10[key]![hour]
                let existing = map[key]!.pm10[hour]
                map[key]!.pm10[hour] = existing.map { ($0 * Double(count) + value) / Double(count + 1) } ?? value
                counts10[key]![hour] = count + 1
            }
        }

        let days = map.values.sorted { $0.id < $1.id }
        guard let first = days.first, let last = days.last else {
            return GridModel(days: [], hourly: true, gridStart: Date(), numWeeks: 0, dayMap: [:])
        }

        let hourly = days.count <= 10
        let weekday = calendar.component(.weekday, from: first.dayStart)
        let gridStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: first.dayStart) ?? first.dayStart
        let daysBetween = calendar.dateComponents([.day], from: gridStart, to: last.dayStart).day ?? 0
        let numWeeks = daysBetween / 7 + 1

        return GridModel(days: days, hourly: hourly, gridStart: gridStart, numWeeks: numWeeks, dayMap: map)
    }

    private func date(_ start: Date, addingDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
    }

    private func monthLabel(_ model: GridModel, week: Int) -> String {
        let current = Self.monthFormatter.string(from: date(model.gridStart, addingDays: week * 7))
        if week == 0 { return current }
        let previous = Self.monthFormatter.string(from: date(model.gridStart, addingDays: (week - 1) * 7))
        return current == previous ? "" : current
    }

    // MARK: - Values & Colors

    private func cellAqi(_ pm25: Double?, _ pm10: Double?) -> Int? {
        var aqi: Int? = nil
        if use25, let value = pm25 {
            aqi = usAqiPm25(value)
        }
        if use10, let value = pm10 {
            let candidate = usAqiPm10(value)
            aqi = aqi.map { max($0, candidate) } ?? candidate
        }
        return aqi
    }

    private func cellValues(_ pm25: Double?, _ pm10: Double?) -> String {
        var parts: [String] = []
        if use25, let value = pm25 {
            parts.append("PM2.5 \(Int(value.rounded()))")
        }
        if use10, let value = pm10 {
            parts.append("PM10 \(Int(value.rounded()))")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func interpolate(_ concentration: Double, _ cLow: Double, _ cHigh: Double, _ iLow: Int, _ iHigh: Int) -> Int {
        Int((Double(iHigh - iLow) / (cHigh - cLow) * (concentration - cLow) + Double(iLow)).rounded())
    }

    private func usAqiPm25(_ pm: Double) -> Int {
        let c = (pm * 10).rounded(.down) / 10
        if c <= 9.0 { return interpolate(c, 0, 9.0, 0, 50) }
        if c <= 35.4 { return interpolate(c, 9.1, 35.4, 51, 100) }
        if c <= 55.4 { return interpolate(c, 35.5, 55.4, 101, 150) }
        if c <= 125.4 { return interpolate(c, 55.5, 125.4, 151, 200) }
        if c <= 225.4 { return interpolate(c, 125.5, 225.4, 201, 300) }
        if c <= 325.4 { return interpolate(c, 225.5, 325.4, 301, 400) }
        return interpolate(c, 325.5, 500.4, 401, 500)
    }

    private func usAqiPm10(_ pm: Double) -> Int {
        let c = pm.rounded(.down)
        if c <= 54 { return interpolate(c, 0, 54, 0, 50) }
        if c <= 154 { return interpolate(c, 55, 154, 51, 100) }
        if c <= 254 { return interpolate(c, 155, 254, 101, 150) }
        if c <= 354 { return interpolate(c, 255, 354, 151, 200) }
        if c <= 424 { return interpolate(c, 355, 424, 201, 300) }
        if c <= 504 { return interpolate(c, 425, 504, 301, 400) }
        return interpolate(c, 505, 604, 401, 500)
    }

    private func usAqiColor(_ value: Int) -> Color {
        switch value {
        case ..<51:  return Color(red: 0/255, green: 228/255, blue: 0/255)
        case ..<101: return Color(red: 255/255, green: 255/255, blue: 0/255)
        case ..<151: return Color(red: 255/255, green: 126/255, blue: 0/255)
        case ..<201: return Color(red: 255/255, green: 0/255, blue: 0/255)
        case ..<301: return Color(red: 143/255, green: 63/255, blue: 151/255)
        default:     return Color(red: 126/255, green: 0/255, blue: 35/255)
        }
    }
}
