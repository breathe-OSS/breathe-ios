// SPDX-License-Identifier: MIT
/*
 * SettingsView.swift
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 SleeperOfSaturn <sanidhya1998@icloud.com>
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

struct SettingsView: View {
    @EnvironmentObject private var viewModel: BreatheViewModel

    @AppStorage("themeMode") private var themeMode = "auto"
    @AppStorage("pinnedOverview") private var pinnedOverview = false
#if DEBUG
    @State private var shotDataSources = false
#endif

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Breathe \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section("Appearance") {
                        Picker("Theme", selection: $themeMode) {
                            Text("System").tag("auto")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.menu)
                    }

                    Section {
                        Picker("AQI Standard", selection: $viewModel.isUsAqi) {
                            Text("US AQI").tag(true)
                            Text("NAQI").tag(false)
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("Air Quality")
                    } footer: {
                        Text("US AQI uses the EPA breakpoints. NAQI is India's national index. The numbers and colours across the app follow this choice.")
                    }

                    Section {
                        Toggle("Pinned Overview", isOn: $pinnedOverview)
                    } footer: {
                        Text("Show every pinned location as a card on Home instead of one at a time.")
                    }

                    Section("About") {
                        NavigationLink {
                            DataSourcesView()
                        } label: {
                            Label("Data Sources", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        LinkRow(title: "Source Code", systemImage: "chevron.left.forwardslash.chevron.right", url: "https://github.com/breathe-OSS/breathe-ios")
                        LinkRow(title: "About Breathe", systemImage: "info.circle", url: "https://about.breatheoss.app")
                        LinkRow(title: "Blog", systemImage: "text.book.closed", url: "https://blogs.breatheoss.app")
                        LinkRow(title: "System Status", systemImage: "waveform.path.ecg", url: "https://status.breatheoss.app")
                        LinkRow(title: "Privacy Policy", systemImage: "hand.raised", url: "https://breatheoss.app/privacy/")
                    }

                    Section {
                        PersonRow(name: "Sidharth \"Siddhi\" Sharma", handle: "sidharthify", role: "Lead Developer")
                        PersonRow(name: "Sannidhya Sharma", handle: "sleeperofsaturn", role: "Developer")
                        PersonRow(name: "Aaditya Gupta", handle: "Flashwreck", role: "Developer")
                        PersonRow(name: "Aditya Choudhary", handle: "empirea9", role: "Contributor")
                        PersonRow(name: "Veer P.S Singh", handle: "Lostless1907", role: "Contributor")
                        PersonRow(name: "Suvesh Moza", handle: "suveshmoza", role: "Contributor")
                            .id("bottom")
                    } header: {
                        Text("Credits")
                    } footer: {
                        Text(versionText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
#if DEBUG
                .task {
                    if ShotHooks.scroll == "bottom" {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    if ShotHooks.screen == "dataSources" {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        shotDataSources = true
                    }
                }
#endif
            }
#if DEBUG
            .navigationDestination(isPresented: $shotDataSources) {
                DataSourcesView()
            }
#endif
            .navigationTitle("Settings")
        }
    }
}

struct LinkRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    let url: String

    var body: some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundStyle(.primary)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

struct PersonRow: View {
    let name: String
    let handle: String
    let role: String

    var body: some View {
        LinkRow(title: name, subtitle: "\(role), @\(handle)", url: "https://github.com/\(handle)")
    }
}
