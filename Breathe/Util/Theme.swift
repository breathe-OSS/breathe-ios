// SPDX-License-Identifier: MIT
/*
 * Theme.swift
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

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum AqiPalette {
    private static let usSteps: [(upper: Int, hex: UInt32, label: String, darkText: Bool)] = [
        (50, 0x00E400, "Good", true),
        (100, 0xFFFF00, "Moderate", true),
        (150, 0xFF7E00, "Unhealthy for Sensitive Groups", true),
        (200, 0xFF0000, "Unhealthy", false),
        (300, 0x8F3F97, "Very Unhealthy", false),
        (Int.max, 0x7E0023, "Hazardous", false),
    ]

    private static let naqiSteps: [(upper: Int, hex: UInt32, label: String, darkText: Bool)] = [
        (50, 0x4ADE80, "Good", true),
        (100, 0xA3E635, "Satisfactory", true),
        (200, 0xFACC15, "Moderate", true),
        (300, 0xFB923C, "Poor", true),
        (400, 0xF87171, "Very Poor", true),
        (Int.max, 0xDC2626, "Severe", false),
    ]

    private static let usAdvice: [String] = [
        "Air quality is satisfactory and poses little or no risk.",
        "Acceptable for most. Unusually sensitive people should think about cutting long outdoor exertion.",
        "Children, older adults and people with heart or lung disease should cut long or heavy outdoor exertion.",
        "Everyone may start to feel effects. Sensitive groups should avoid long outdoor exertion.",
        "Health alert. Everyone should cut outdoor exertion and sensitive groups should stay indoors.",
        "Emergency conditions. Everyone should avoid outdoor activity.",
    ]

    private static let naqiAdvice: [String] = [
        "Minimal impact.",
        "Minor breathing discomfort for sensitive people.",
        "Breathing discomfort for people with lung or heart disease, children and older adults.",
        "Breathing discomfort for most people on long exposure.",
        "Respiratory illness on long exposure.",
        "Affects healthy people and seriously affects people with existing disease.",
    ]

    private static func step(_ value: Int, isUsAqi: Bool) -> (upper: Int, hex: UInt32, label: String, darkText: Bool) {
        let steps = isUsAqi ? usSteps : naqiSteps
        return steps.first { value <= $0.upper } ?? steps[steps.count - 1]
    }

    static func color(_ value: Int, isUsAqi: Bool) -> Color {
        Color(hex: step(value, isUsAqi: isUsAqi).hex)
    }

    static func onColor(_ value: Int, isUsAqi: Bool) -> Color {
        if step(value, isUsAqi: isUsAqi).darkText {
            return .black
        }
        return .white
    }

    static func label(_ value: Int, isUsAqi: Bool) -> String {
        step(value, isUsAqi: isUsAqi).label
    }

    static func standardName(isUsAqi: Bool) -> String {
        isUsAqi ? "US AQI" : "NAQI"
    }

    static func samples(isUsAqi: Bool) -> [Int] {
        isUsAqi ? [25, 75, 125, 175, 250, 400] : [25, 75, 150, 250, 350, 450]
    }

    static func bands(isUsAqi: Bool) -> [AqiBand] {
        let steps = isUsAqi ? usSteps : naqiSteps
        let advice = isUsAqi ? usAdvice : naqiAdvice
        var lower = 0
        return steps.enumerated().map { index, entry in
            let upper = min(entry.upper, 500)
            let band = AqiBand(
                lower: lower,
                upper: upper,
                color: Color(hex: entry.hex),
                label: entry.label,
                advice: advice[index]
            )
            lower = upper
            return band
        }
    }

    static func lineGradient(low: Int, high: Int, isUsAqi: Bool) -> LinearGradient {
        guard high > low else {
            let color = AqiPalette.color(high, isUsAqi: isUsAqi)
            return LinearGradient(colors: [color, color], startPoint: .top, endPoint: .bottom)
        }
        let span = Double(high - low)
        var stops: [Gradient.Stop] = [Gradient.Stop(color: color(high, isUsAqi: isUsAqi), location: 0)]
        for band in bands(isUsAqi: isUsAqi).reversed() where band.lower > low && band.lower < high {
            let location = Double(high - band.lower) / span
            stops.append(Gradient.Stop(color: band.color, location: location))
            stops.append(Gradient.Stop(color: color(band.lower, isUsAqi: isUsAqi), location: location))
        }
        stops.append(Gradient.Stop(color: color(low, isUsAqi: isUsAqi), location: 1))
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}

struct AqiBand: Identifiable {
    let lower: Int
    let upper: Int
    let color: Color
    let label: String
    let advice: String

    var id: Int { lower }

    var rangeText: String {
        let start = lower == 0 ? 0 : lower + 1
        if upper >= 500 {
            return "\(start)+"
        }
        return "\(start) to \(upper)"
    }

    func contains(_ value: Int) -> Bool {
        if lower == 0 {
            return value <= upper
        }
        return value > lower && (value <= upper || upper >= 500)
    }
}

enum SeriesPalette {
    static let pm25 = Color.blue
    static let pm10 = Color.purple
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

extension View {
    @ViewBuilder
    func floatingGlass() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: Capsule())
        } else {
            background(.regularMaterial, in: Capsule())
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
