// SPDX-License-Identifier: MIT
/*
 * AqiGauge.swift
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

struct AqiGauge: View {
    let aqi: Int
    let isUsAqi: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gap: CGFloat = 3

    var body: some View {
        let bands = AqiPalette.bands(isUsAqi: isUsAqi)
        let index = bands.firstIndex { $0.contains(aqi) } ?? bands.count - 1
        let band = bands[index]
        let fraction = min(max(Double(aqi - band.lower) / Double(max(band.upper - band.lower, 1)), 0), 1)

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let segment = (geo.size.width - gap * CGFloat(bands.count - 1)) / CGFloat(bands.count)
                let markerX = CGFloat(index) * (segment + gap) + segment * CGFloat(fraction)

                ZStack(alignment: .leading) {
                    HStack(spacing: gap) {
                        ForEach(Array(bands.enumerated()), id: \.element.id) { offset, entry in
                            Capsule()
                                .fill(entry.color)
                                .frame(width: segment, height: offset == index ? 10 : 6)
                        }
                    }
                    .frame(height: 22)

                    Capsule()
                        .fill(Color.primary)
                        .frame(width: 4, height: 22)
                        .offset(x: min(max(markerX - 2, 0), geo.size.width - 4))
                        .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.75), value: markerX)
                }
            }
            .frame(height: 22)

            HStack {
                Text(band.rangeText)
                    .monospacedDigit()
                Spacer()
                if index + 1 < bands.count {
                    Text("Next band at \(band.upper + 1)")
                        .monospacedDigit()
                } else {
                    Text("Top of the scale")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AQI scale")
        .accessibilityValue("\(aqi), \(band.label), band \(band.rangeText)")
        .accessibilityHint("Shows what each band means")
        .accessibilityAddTraits(.isButton)
    }
}

struct AqiScaleSheet: View {
    let aqi: Int
    let isUsAqi: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AqiPalette.bands(isUsAqi: isUsAqi).reversed()) { band in
                        let isCurrent = band.contains(aqi)

                        HStack(alignment: .top, spacing: 12) {
                            Capsule()
                                .fill(band.color)
                                .frame(width: 6)
                                .frame(minHeight: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(band.label)
                                        .font(.headline)
                                    Spacer()
                                    Text(band.rangeText)
                                        .font(.subheadline)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                Text(band.advice)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if isCurrent {
                                    Label("Now at \(aqi)", systemImage: "location.fill")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(
                            ZStack {
                                Color(.secondarySystemGroupedBackground)
                                if isCurrent {
                                    band.color.opacity(colorScheme == .dark ? 0.22 : 0.16)
                                }
                            }
                        )
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text(isUsAqi
                         ? "US AQI uses the EPA breakpoints, with PM2.5 on the 2024 revision. Change the standard in Settings."
                         : "NAQI is India's national index. Change the standard in Settings.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(AqiPalette.standardName(isUsAqi: isUsAqi))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
