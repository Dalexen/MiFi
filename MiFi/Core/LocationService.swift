import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    static let didUpdate = Notification.Name("MiFiLocationDidUpdate")

    private let manager = CLLocationManager()
    private(set) var location: CLLocation?

    var isDenied: Bool {
        let s = manager.authorizationStatus
        return s == .denied || s == .restricted
    }

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 50
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if !isDenied { manager.startUpdatingLocation() }
        NotificationCenter.default.post(name: LocationService.didUpdate, object: nil)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        location = last
        NotificationCenter.default.post(name: LocationService.didUpdate, object: nil)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NotificationCenter.default.post(name: LocationService.didUpdate, object: nil)
    }
}
