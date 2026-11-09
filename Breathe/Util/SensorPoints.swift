// SPDX-License-Identifier: MIT
/*
 * SensorPoints.swift - Puts each ground sensor on the map using its reading and its coordinates
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
import CoreLocation

struct SensorPoint: Identifiable {
    // sensor names only have to be unique inside their zone
    var id: String { "\(zoneId)/\(name)" }

    let zoneId: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let reading: NodeReading
    let info: SensorInfo

    var isOffline: Bool { reading.pm25 == nil }
}

// readings come from each zone's nodes and coordinates from /sensor-info,
// matched by sensor name. the zone name is tried first since names only
// have to be unique per zone, a bare name match is the fallback. sensors
// without coordinates can't go on the map and are left out
func buildSensorPoints(zones: [AqiResponse], sensorInfos: [SensorInfo]) -> [SensorPoint] {
    var points: [SensorPoint] = []
    for zone in zones {
        for (name, reading) in zone.nodes ?? [:] {
            let sameZone = sensorInfos.first { $0.zone == zone.zoneName && $0.name == name }
            let byName = sensorInfos.filter { $0.name == name }
            guard let info = sameZone ?? (byName.count == 1 ? byName.first : nil) else {
                continue
            }
            guard let lat = info.latitude, let lon = info.longitude else {
                continue
            }
            points.append(
                SensorPoint(
                    zoneId: zone.zoneId,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    reading: reading,
                    info: info
                )
            )
        }
    }
    return points.sorted { $0.id < $1.id }
}
