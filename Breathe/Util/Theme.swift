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

    static func gradientStops(isUsAqi: Bool) -> [Gradient.Stop] {
        let steps = isUsAqi ? usSteps : naqiSteps
        var lower = 0
        return steps.map { entry in
            let stop = Gradient.Stop(color: Color(hex: entry.hex), location: Double(lower) / 500)
            if entry.upper < 500 {
                lower = entry.upper + 1
            }
            return stop
        }
    }
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
