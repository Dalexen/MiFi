import UIKit
import MapKit

final class MapViewController: UIViewController, MKMapViewDelegate {
    private let mapView = MKMapView()
    private var didCenter = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Map"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentAddNetwork))

        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        mapView.delegate = self
        view.addSubview(mapView)

        let tracking = MKUserTrackingButton(mapView: mapView)
        tracking.translatesAutoresizingMaskIntoConstraints = false
        tracking.layer.cornerRadius = 8
        tracking.backgroundColor = .secondarySystemBackground
        view.addSubview(tracking)
        NSLayoutConstraint.activate([
            tracking.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            tracking.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tracking.widthAnchor.constraint(equalToConstant: 44),
            tracking.heightAnchor.constraint(equalToConstant: 44)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NetworkStore.didUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: LocationService.didUpdate, object: nil)
        reload()
    }

    @objc private func reload() {
        if !didCenter, let here = LocationService.shared.location {
            didCenter = true
            mapView.setRegion(MKCoordinateRegion(center: here.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000), animated: false)
        }
        let old = mapView.annotations.filter { $0 is NetworkAnnotation }
        mapView.removeAnnotations(old)
        mapView.addAnnotations(NetworkStore.shared.networks.map(NetworkAnnotation.init))
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let network = annotation as? NetworkAnnotation else { return nil }
        let id = "network"
        let pin = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: network, reuseIdentifier: id)
        pin.annotation = network
        pin.canShowCallout = true
        pin.markerTintColor = .systemBlue
        pin.glyphImage = UIImage(systemName: "wifi")
        pin.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        return pin
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let annotation = view.annotation as? NetworkAnnotation else { return }
        navigationController?.pushViewController(DetailViewController(network: annotation.network), animated: true)
    }
}
