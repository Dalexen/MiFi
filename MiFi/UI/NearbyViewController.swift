import UIKit
import MapKit

final class NearbyViewController: UITableViewController, UISearchResultsUpdating {
    private let search = UISearchController(searchResultsController: nil)
    private let statusLabel = UILabel()
    private let distanceFormatter = MKDistanceFormatter()
    private var items: [WiFiNetwork] = []

    init() { super.init(style: .grouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nearby"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentAddNetwork))

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search"
        navigationItem.searchController = search
        definesPresentationContext = true

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)

        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .preferredFont(forTextStyle: .body)

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NetworkStore.didUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: LocationService.didUpdate, object: nil)
        reload()
    }

    @objc private func pulledToRefresh() {
        NetworkStore.shared.refresh(force: true)
        if !NetworkStore.shared.isLoading { refreshControl?.endRefreshing() }
    }

    @objc private func reload() {
        let store = NetworkStore.shared
        if !store.isLoading { refreshControl?.endRefreshing() }

        let query = (search.searchBar.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        items = query.isEmpty ? store.networks : store.networks.filter {
            $0.ssid.lowercased().contains(query) || $0.venue.lowercased().contains(query)
        }

        if items.isEmpty {
            if LocationService.shared.isDenied {
                statusLabel.text = "Location access is off.\nTurn it on in Settings to find networks near you."
            } else if LocationService.shared.location == nil || store.isLoading {
                statusLabel.text = "Looking for networks…"
            } else if store.lastError != nil {
                statusLabel.text = "Couldn't load networks.\nPull down to try again."
            } else if !query.isEmpty {
                statusLabel.text = "No Results"
            } else {
                statusLabel.text = "No networks here yet.\nTap + to share the first one."
            }
            statusLabel.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 200)
            tableView.backgroundView = statusLabel
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }

    func updateSearchResults(for searchController: UISearchController) {
        reload()
    }

    // MARK: - Table view

    override func numberOfSections(in tableView: UITableView) -> Int { items.isEmpty ? 0 : 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Networks Near You" }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Passwords are shared by the community. Only join networks you are allowed to use."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "network")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "network")
        let n = items[indexPath.row]
        cell.textLabel?.text = n.ssid
        var parts: [String] = []
        if !n.venue.isEmpty { parts.append(n.venue) }
        if let d = NetworkStore.shared.distance(to: n) { parts.append(distanceFormatter.string(fromDistance: d)) }
        cell.detailTextLabel?.text = parts.joined(separator: " · ")
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.imageView?.image = UIImage(systemName: n.isOpen ? "wifi" : "lock.fill")
        cell.imageView?.tintColor = .systemBlue
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(DetailViewController(network: items[indexPath.row]), animated: true)
    }
}
