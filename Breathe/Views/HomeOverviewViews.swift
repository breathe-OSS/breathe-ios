// SPDX-License-Identifier: MIT
/*
 * HomeOverviewViews.swift
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

@MainActor
struct CountingText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
    }
}

struct SnapshotEntry: Identifiable {
    let zone: Zone
    let aqi: Int

    var id: String { zone.id }
}

struct WelcomeView: View {
    let worstEntries: [SnapshotEntry]
    let bestEntries: [SnapshotEntry]
    let isUsAqi: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onSelect: (Zone) -> Void
    let onBrowse: () -> Void

    @State private var hasAppeared = false
    @State private var badgeRotation = 0.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor.opacity(0.25))
                        .rotationEffect(.degrees(badgeRotation))

                    Image(systemName: "wind")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Text("Welcome to Breathe")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)

                Text("Breathe tracks the air across Jammu Kashmir & Ladakh. Pin a place to get started and it will live on your Home screen.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Right Now")
                        .font(.system(.headline, design: .rounded))

                    Text("Live ground sensor readings. Tap one to pin it")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                HStack(alignment: .top, spacing: 12) {
                    SnapshotCard(
                        title: "Most Polluted",
                        systemImage: "exclamationmark.triangle.fill",
                        entries: worstEntries,
                        isUsAqi: isUsAqi,
                        delayOffset: 0,
                        onSelect: onSelect
                    )

                    SnapshotCard(
                        title: "Cleanest",
                        systemImage: "wind",
                        entries: bestEntries,
                        isUsAqi: isUsAqi,
                        delayOffset: worstEntries.count,
                        onSelect: onSelect
                    )
                }

                HStack {
                    Spacer()

                    Button("Browse all locations") {
                        onBrowse()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                }
            }
            .padding(24)
            .scaleEffect(hasAppeared ? 1 : 0.92)
            .opacity(hasAppeared ? 1 : 0)
        }
        .interactiveDismissDisabled()
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    badgeRotation = 360
                }
            } else {
                hasAppeared = true
            }
        }
    }
}

private struct SnapshotCard: View {
    let title: String
    let systemImage: String
    let entries: [SnapshotEntry]
    let isUsAqi: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delayOffset: Int
    let onSelect: (Zone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                SnapshotRow(
                    entry: entry,
                    isUsAqi: isUsAqi,
                    delay: Double(delayOffset + index) * 0.07,
                    onSelect: onSelect
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct SnapshotRow: View {
    let entry: SnapshotEntry
    let isUsAqi: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    let onSelect: (Zone) -> Void

    @State private var hasAppeared = false

    var body: some View {
        Button {
            onSelect(entry.zone)
        } label: {
            HStack {
                Text(entry.zone.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer(minLength: 8)

                CountingText(value: hasAppeared ? Double(entry.aqi) : 0)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(AqiPalette.color(entry.aqi, isUsAqi: isUsAqi))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 16)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
    }
}

struct PinnedHintCard: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pin.fill")
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("That's how Breathe works")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)

                Text("Your pinned locations live up here. Pin more from Search or the Map, and tap one to switch to it.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()

                    Button("Got it") {
                        onDismiss()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }
}

struct PinnedOverviewCard: View {
    let zone: Zone
    let aqi: Int?
    let isUsAqi: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = aqi.map { AqiPalette.color($0, isUsAqi: isUsAqi) } ?? .gray
        let isLive = zone.provider?.localizedCaseInsensitiveContains("airgradient") == true

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if isLive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Live ground sensors")
                }
            }

            if let aqi = aqi {
                Text("\(aqi)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(AqiPalette.label(aqi, isUsAqi: isUsAqi))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                ProgressView()
                    .frame(height: 48)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(color.opacity(colorScheme == .dark ? 0.22 : 0.16))
                )
        )
        .accessibilityElement(children: .combine)
    }
}
