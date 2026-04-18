//
//  NodeReadingCard.swift
//  Breathe
//
//  * Copyright (C) 2026 The Breathe Open Source Project
//  * Copyright (C) 2026 sidharthify <wednisegit@gmail.com>
//

import SwiftUI

struct NodeReadingCard: View {
    let nodeName: String
    let reading: NodeReading
    let isUsAqi: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showingSensorInfo = false
    @EnvironmentObject private var viewModel: BreatheViewModel
    
    var body: some View {
        let isDown = reading.pm25 == nil
        let displayAqi = reading.aqi
        var aqiLabelStr = "Unknown"
        var aqiColor = Color.gray
        
        if !isDown, let aqi = displayAqi {
            aqiLabelStr = aqiLabel(aqi)
            aqiColor = aqiColorFor(aqi: aqi, isUsAqi: isUsAqi)
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(nodeName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { showingSensorInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .disabled(isDown && getSensorInfo() == nil) // Optional disable if totally unknown, but good to have info
            }
            
            Divider()
            
            if isDown {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Sensor reading currently unavailable")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    nodeInfoRow(label: "AQI", value: displayAqi.map { "\($0)" } ?? "—")
                    nodeInfoRow(label: "AQI Standard", value: aqiLabelStr)
                        .foregroundColor(aqiColor)
                    
                    if let pm25 = reading.pm25 {
                        nodeInfoRow(label: "PM2.5", value: String(format: "%.1f µg/m³", pm25))
                    } else {
                        nodeInfoRow(label: "PM2.5", value: "—")
                    }
                    
                    if let pm10 = reading.pm10 {
                        nodeInfoRow(label: "PM10", value: String(format: "%.1f µg/m³", pm10))
                    } else {
                        nodeInfoRow(label: "PM10", value: "—")
                    }
                    
                    if let temp = reading.temp {
                        nodeInfoRow(label: "Temperature", value: String(format: "%.1f °C", temp))
                    }
                    else {
                        nodeInfoRow(label: "Temperature", value: "—")
                    }
                    if let humidity = reading.humidity {
                        nodeInfoRow(label: "Humidity", value: String(format: "%.1f%%", humidity))
                    } else {
                        nodeInfoRow(label: "Humidity", value: "—")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDown ? Color.orange.opacity(0.5) : aqiColor.opacity(0.3), lineWidth: 1)
        )
        .onLongPressGesture {
            showingSensorInfo.toggle()
        }
        .sheet(isPresented: $showingSensorInfo) {
            if let info = getSensorInfo() {
                SensorInfoSheet(info: info, isUsAqi: isUsAqi)
                    .presentationDetents([.medium, .large])
            } else {
                Text("No hardware details available for this sensor.")
                    .font(.headline)
                    .padding()
                    .presentationDetents([.medium])
            }
        }
    }
    
    @ViewBuilder
    private func nodeInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
        }
    }
    
    private func getSensorInfo() -> SensorInfo? {
        return viewModel.sensorInfos.first { $0.name == nodeName }
    }
    
    // Formatting Helpers copied from HomeView logic
    private func aqiColorFor(aqi: Int, isUsAqi: Bool) -> Color {
        if isUsAqi {
            switch aqi {
            case ..<51:  return Color(red: 0/255, green: 228/255, blue: 0/255)
            case ..<101: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<151: return Color(red: 255/255, green: 126/255, blue: 0/255)
            case ..<201: return Color(red: 255/255, green: 0/255, blue: 0/255)
            case ..<301: return Color(red: 143/255, green: 63/255, blue: 151/255)
            default:     return Color(red: 126/255, green: 0/255, blue: 35/255)
            }
        } else {
            switch aqi {
            case ..<51:  return Color(red: 0/255, green: 176/255, blue: 80/255)
            case ..<101: return Color(red: 146/255, green: 208/255, blue: 80/255)
            case ..<201: return Color(red: 255/255, green: 255/255, blue: 0/255)
            case ..<301: return Color(red: 244/255, green: 145/255, blue: 28/255)
            case ..<401: return Color(red: 233/255, green: 63/255, blue: 51/255)
            default:     return Color(red: 175/255, green: 45/255, blue: 36/255)
            }
        }
    }
    
    private func aqiLabel(_ value: Int) -> String {
        switch value {
        case ..<51:  return "Good"
        case ..<101: return "Moderate"
        case ..<151: return "Unhealthy for Sensitive Groups"
        case ..<201: return "Unhealthy"
        case ..<301: return "Very Unhealthy"
        default:     return "Hazardous"
        }
    }

    private var cardBackground: Color {
#if os(iOS)
        return Color(UIColor.secondarySystemGroupedBackground)
#elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
#else
        return Color.gray.opacity(0.1)
#endif
    }
}

struct SensorInfoSheet: View {
    let info: SensorInfo
    let isUsAqi: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Hardware Information")) {
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text(info.provider)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Model")
                        Spacer()
                        Text(info.model)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Location ID")
                        Spacer()
                        Text("\(info.locationId)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Install Date")
                        Spacer()
                        Text(info.installationDate)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("\(info.name) Status")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}
