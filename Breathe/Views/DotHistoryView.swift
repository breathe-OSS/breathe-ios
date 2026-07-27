// SPDX-License-Identifier: MIT
/*
 * DotHistoryView.swift
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

struct DotHistoryView: View {
    let history: [HistoryPoint]
    let isUsAqi: Bool

    @State private var selectedIndex: Int? = nil

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"
        return formatter
    }()

    private var points: [HistoryPoint] {
        history.sorted { $0.ts < $1.ts }
    }

    private func value(at index: Int) -> Int {
        let point = points[index]
        return isUsAqi ? (point.usAqi ?? point.aqi) : point.aqi
    }

    private func hourLabel(_ index: Int) -> String {
        Self.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(points[index].ts)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("24-Hour Trend")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let index = selectedIndex, points.indices.contains(index) {
                    Text("AQI \(value(at: index))  ·  \(hourLabel(index))")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                } else {
                    Text("Tap a bar for details")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if points.isEmpty {
                Text("No data available for the last 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 3) {
                    ForEach(points.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(aqiColor(value(at: index)))
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.primary, lineWidth: 1.5)
                                    .opacity(selectedIndex == index ? 1 : 0)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    selectedIndex = selectedIndex == index ? nil : index
                                }
                            }
                    }
                }
                .frame(height: 120)

                HStack {
                    Text(hourLabel(0))
                    Spacer()
                    if points.count > 2 {
                        Text(hourLabel(points.count / 2))
                        Spacer()
                    }
                    Text(hourLabel(points.count - 1))
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)

                legend
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(chartCardBackground)
        )
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Good")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
            ForEach(legendReps, id: \.self) { rep in
                RoundedRectangle(cornerRadius: 2)
                    .fill(aqiColor(rep))
                    .frame(width: 16, height: 6)
            }
            Text(isUsAqi ? "Hazardous" : "Severe")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var legendReps: [Int] {
        isUsAqi ? [25, 75, 125, 175, 250, 400] : [25, 75, 150, 250, 350, 450]
    }

    private var chartCardBackground: Color {
#if os(iOS)
        return Color(.secondarySystemBackground)
#elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
#else
        return Color.gray.opacity(0.15)
#endif
    }

    private func aqiColor(_ value: Int) -> Color {
        if isUsAqi {
            switch value {
            case ..<51:  return Color(red: 0/255, green: 228/255, blue: 0/255)
            case ..<101: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<151: return Color(red: 255/255, green: 126/255, blue: 0/255)
            case ..<201: return Color(red: 255/255, green: 0/255, blue: 0/255)
            case ..<301: return Color(red: 143/255, green: 63/255, blue: 151/255)
            default:     return Color(red: 126/255, green: 0/255, blue: 35/255)
            }
        } else {
            switch value {
            case ..<51:  return Color(red: 0/255, green: 176/255, blue: 80/255)
            case ..<101: return Color(red: 146/255, green: 208/255, blue: 80/255)
            case ..<201: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<301: return Color(red: 244/255, green: 145/255, blue: 28/255)
            case ..<401: return Color(red: 233/255, green: 63/255, blue: 51/255)
            default:     return Color(red: 175/255, green: 45/255, blue: 36/255)
            }
        }
    }
}
