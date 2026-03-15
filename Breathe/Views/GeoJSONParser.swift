import Foundation
import CoreLocation
import MapKit

struct GeoJSONPolygon {
    let coordinates: [CLLocationCoordinate2D]
}

class GeoJSONParser {
    static func parseFeatures(from fileName: String) -> [[CLLocationCoordinate2D]] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "geojson") else {
            print("Failed to find \(fileName).geojson")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let features = json["features"] as? [[String: Any]] else {
                return []
            }
            
            var polygons: [[CLLocationCoordinate2D]] = []
            
            for feature in features {
                guard let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String else {
                    continue
                }
                
                if type == "Polygon" {
                    if let coords = geometry["coordinates"] as? [[[Double]]] {
                        for ring in coords {
                            polygons.append(ring.compactMap {
                                if $0.count >= 2 { return CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } else { return nil }
                            })
                        }
                    }
                } else if type == "MultiPolygon" {
                    if let multiCoords = geometry["coordinates"] as? [[[[Double]]]] {
                        for polygon in multiCoords {
                            for ring in polygon {
                                polygons.append(ring.compactMap {
                                    if $0.count >= 2 { return CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } else { return nil }
                                })
                            }
                        }
                    }
                }
            }
            return polygons
        } catch {
            print("Error parsing \(fileName).geojson: \(error)")
            return []
        }
    }
}
