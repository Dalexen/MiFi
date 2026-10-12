import CoreLocation
import MapKit

struct WiFiNetwork: Codable {
    let id: String
    let ssid: String
    let password: String
    let security: String
    let venue: String
    let lat: Double
    let lon: Double
    let by: String
    let added: String
    let reports: Int

    enum CodingKeys: String, CodingKey {
        case id, ssid, password, security, venue, lat, lon, by, added, reports
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        ssid = try c.decode(String.self, forKey: .ssid)
        lat = try c.decode(Double.self, forKey: .lat)
        lon = try c.decode(Double.self, forKey: .lon)
        password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
        security = try c.decodeIfPresent(String.self, forKey: .security) ?? "WPA2"
        venue = try c.decodeIfPresent(String.self, forKey: .venue) ?? ""
        by = try c.decodeIfPresent(String.self, forKey: .by) ?? ""
        added = try c.decodeIfPresent(String.self, forKey: .added) ?? ""
        reports = try c.decodeIfPresent(Int.self, forKey: .reports) ?? 0
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    var location: CLLocation { CLLocation(latitude: lat, longitude: lon) }
    var isOpen: Bool { security == "Open" }
}

struct TileFile: Codable {
    let networks: [WiFiNetwork]
}

final class NetworkAnnotation: NSObject, MKAnnotation {
    let network: WiFiNetwork
    var coordinate: CLLocationCoordinate2D { network.coordinate }
    var title: String? { network.ssid }
    var subtitle: String? { network.venue.isEmpty ? network.security : network.venue }

    init(_ network: WiFiNetwork) {
        self.network = network
    }
}
