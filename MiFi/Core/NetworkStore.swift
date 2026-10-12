import CoreLocation

enum DataError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned status \(code)."
        }
    }
}

/// Reads the crowd-sourced database straight from the GitHub repo (static JSON tiles).
final class DataService {
    static let shared = DataService()

    func fetchNearby(lat: Double, lon: Double, completion: @escaping (Result<[WiFiNetwork], Error>) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var all: [WiFiNetwork] = []
        var firstError: Error?

        for tile in Geohash.tiles(around: lat, lon: lon) {
            guard let url = URL(string: Config.tileBaseURL + tile + ".json") else { continue }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            group.enter()
            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { group.leave() }
                lock.lock()
                defer { lock.unlock() }
                if let error = error {
                    firstError = firstError ?? error
                    return
                }
                guard let http = response as? HTTPURLResponse else { return }
                if http.statusCode == 404 { return } // no networks in this tile yet
                guard http.statusCode == 200, let data = data else {
                    firstError = firstError ?? DataError.badStatus(http.statusCode)
                    return
                }
                if let file = try? JSONDecoder().decode(TileFile.self, from: data) {
                    all.append(contentsOf: file.networks)
                }
            }.resume()
        }

        group.notify(queue: .main) {
            if all.isEmpty, let error = firstError {
                completion(.failure(error))
            } else {
                completion(.success(all))
            }
        }
    }
}

final class NetworkStore {
    static let shared = NetworkStore()
    static let didUpdate = Notification.Name("MiFiNetworksDidUpdate")
    static let hideAfterReports = 3

    private(set) var networks: [WiFiNetwork] = []
    private(set) var isLoading = false
    private(set) var lastError: Error?
    private var lastFetch: CLLocation?

    private init() {
        NotificationCenter.default.addObserver(forName: LocationService.didUpdate, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh(force: Bool = false) {
        guard !isLoading, let here = LocationService.shared.location else { return }
        if !force, let last = lastFetch, last.distance(from: here) < 500, lastError == nil { return }
        isLoading = true
        lastError = nil
        post()
        DataService.shared.fetchNearby(lat: here.coordinate.latitude, lon: here.coordinate.longitude) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let found):
                var seen = Set<String>()
                let unique = found.filter { $0.reports < NetworkStore.hideAfterReports && seen.insert($0.id).inserted }
                self.networks = unique.sorted { $0.location.distance(from: here) < $1.location.distance(from: here) }
                self.lastFetch = here
            case .failure(let error):
                self.lastError = error
            }
            self.post()
        }
    }

    func distance(to network: WiFiNetwork) -> CLLocationDistance? {
        LocationService.shared.location.map { network.location.distance(from: $0) }
    }

    private func post() {
        NotificationCenter.default.post(name: NetworkStore.didUpdate, object: nil)
    }
}
