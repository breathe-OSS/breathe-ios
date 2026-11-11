// SPDX-License-Identifier: MIT
/*
 * ChartComponents.swift
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

struct ChartReadout<Trailing: View>: View {
    let caption: String
    let value: String
    let detail: String
    var tint: Color? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let tint {
                        Circle()
                            .fill(tint)
                            .frame(width: 10, height: 10)
                    }
                    Text(value)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .accessibilityElement(children: .combine)
    }
}

struct AqiLegend: View {
    let isUsAqi: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("Good")
            ForEach(AqiPalette.bands(isUsAqi: isUsAqi)) { band in
                Capsule()
                    .fill(band.color)
                    .frame(height: 6)
                    .frame(maxWidth: 28)
            }
            Text(isUsAqi ? "Hazardous" : "Severe")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

struct ChartSelectionDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2.5))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}
