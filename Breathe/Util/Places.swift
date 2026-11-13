// SPDX-License-Identifier: MIT
/*
 * Places.swift - Districts, raw readings and health advice for per sensor zones
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

let divisionOrder = ["Jammu", "Kashmir", "Ladakh"]

func divisionRank(_ division: String?) -> Int {
    guard let division, let index = divisionOrder.firstIndex(of: division) else {
        return divisionOrder.count
    }
    return index
}

func placeLine(district: String?, division: String?) -> String {
    guard let district, !district.isEmpty else {
        return ""
    }
    guard let division, !division.isEmpty else {
        return "Part of the \(district) district"
    }
    return "Part of the \(district) district in \(division)"
}

struct RawPoint: Identifiable {
    var id: String { title }
    let title: String
    let text: String
}

let rawExplainerPoints: [RawPoint] = [
    RawPoint(
        title: "PM2.5 and PM10",
        text: "The laser counter's own numbers, before AirGradient's correction. The correction mostly lowers PM2.5, more so in humid air, so raw usually reads higher."
    ),
    RawPoint(
        title: "Temperature and humidity",
        text: "Read inside the sensor's case, which warms up in the sun. Raw temperature runs a few degrees high in the afternoon and raw humidity runs low."
    ),
    RawPoint(
        title: "AQI, advice and charts",
        text: "The index, its colour, the health advice, the cigarette count and every chart are worked out again from the raw numbers."
    ),
    RawPoint(
        title: "Satellite estimates",
        text: "Places without a sensor have no raw readings, so they don't change."
    ),
    RawPoint(
        title: "History",
        text: "Raw history only goes back to the day Breathe started keeping it. Hours before that show as gaps."
    ),
    RawPoint(
        title: "Which one to trust",
        text: "Calibrated is closer to what a reference monitor would show. Raw is useful for checking the sensor itself or comparing it with another device."
    ),
]

struct HealthAdvice {
    let title: String
    let text: String
}

private let healthAdvice: [HealthAdvice] = [
    HealthAdvice(title: "Good time to be outside", text: "The air is clean. Open the windows and enjoy it."),
    HealthAdvice(title: "Fine for most people", text: "If you're unusually sensitive to pollution, go easier on long outdoor workouts."),
    HealthAdvice(
        title: "Sensitive groups take care",
        text: "Kids, older adults and anyone with asthma or heart disease should cut back on long or heavy exertion outside."
    ),
    HealthAdvice(title: "Cut back outdoors", text: "Everyone should ease off heavy exertion outside. Sensitive groups should keep outdoor time short."),
    HealthAdvice(
        title: "Avoid exertion outside",
        text: "Keep windows shut and run a purifier if you have one. Wear an N95 if you need to be out for long."
    ),
    HealthAdvice(title: "Stay indoors", text: "Keep windows and doors shut. If you have to go out, wear a well fitted N95."),
]

func aqiBandIndex(_ aqi: Int, isUsAqi: Bool) -> Int {
    let limits = isUsAqi ? [50, 100, 150, 200, 300] : [50, 100, 200, 300, 400]
    for (index, limit) in limits.enumerated() where aqi <= limit {
        return index
    }
    return limits.count
}

func healthAdviceFor(_ aqi: Int, isUsAqi: Bool) -> HealthAdvice {
    healthAdvice[aqiBandIndex(aqi, isUsAqi: isUsAqi)]
}

private func interpolate(_ c: Double, _ cLow: Double, _ cHigh: Double, _ iLow: Int, _ iHigh: Int) -> Int {
    Int(((Double(iHigh - iLow) / (cHigh - cLow)) * (c - cLow) + Double(iLow)).rounded())
}

func usAqiFromPm25(_ pm25: Double) -> Int {
    switch pm25 {
    case ...9.0: return interpolate(pm25, 0, 9, 0, 50)
    case ...35.4: return interpolate(pm25, 9.1, 35.4, 51, 100)
    case ...55.4: return interpolate(pm25, 35.5, 55.4, 101, 150)
    case ...125.4: return interpolate(pm25, 55.5, 125.4, 151, 200)
    case ...225.4: return interpolate(pm25, 125.5, 225.4, 201, 300)
    case ...325.4: return interpolate(pm25, 225.5, 325.4, 301, 400)
    default: return interpolate(pm25, 325.5, 500, 401, 500)
    }
}

func naqiFromPm25(_ pm25: Double) -> Int {
    let c = pm25.rounded()
    switch c {
    case ...30: return interpolate(c, 0, 30, 0, 50)
    case ...60: return interpolate(c, 31, 60, 51, 100)
    case ...90: return interpolate(c, 61, 90, 101, 200)
    case ...120: return interpolate(c, 91, 120, 201, 300)
    case ...250: return interpolate(c, 121, 250, 301, 400)
    default: return min(interpolate(c, 251, 380, 401, 500), 500)
    }
}

func aqiFromPm25(_ pm25: Double, isUsAqi: Bool) -> Int {
    isUsAqi ? usAqiFromPm25(pm25) : naqiFromPm25(pm25)
}
