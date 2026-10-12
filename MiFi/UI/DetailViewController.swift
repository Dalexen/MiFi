import UIKit
import MapKit
import NetworkExtension

final class DetailViewController: UITableViewController {
    private enum Row {
        case info(String, String)
        case password
        case copy
        case join
        case directions
        case report
    }

    private let network: WiFiNetwork
    private var sections: [(header: String?, footer: String?, rows: [Row])] = []

    init(network: WiFiNetwork) {
        self.network = network
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = network.ssid
        navigationItem.largeTitleDisplayMode = .never

        var info: [Row] = [.info("Network", network.ssid)]
        if !network.isOpen { info.append(.password) }
        info.append(.info("Security", network.security))
        if !network.venue.isEmpty { info.append(.info("Place", network.venue)) }
        if let d = NetworkStore.shared.distance(to: network) {
            info.append(.info("Distance", MKDistanceFormatter().string(fromDistance: d)))
        }
        if !network.by.isEmpty { info.append(.info("Shared by", "@" + network.by)) }

        var actions: [Row] = []
        if !network.isOpen { actions.append(.copy) }
        actions.append(.join)
        actions.append(.directions)

        sections = [
            (nil, nil, info),
            (nil, nil, actions),
            (nil, "Passwords come from the community and may be out of date. Reports from three people remove a network.", [.report])
        ]
    }

    // MARK: - Table view

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section].footer }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .info(let title, let value):
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = value
            cell.selectionStyle = .none
        case .password:
            cell.textLabel?.text = "Password"
            cell.detailTextLabel?.text = network.password
            cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        case .copy:
            styleAction(cell, "Copy Password", color: .systemBlue)
        case .join:
            styleAction(cell, "Join Network", color: .systemBlue)
        case .directions:
            styleAction(cell, "Get Directions", color: .systemBlue)
        case .report:
            styleAction(cell, "Report Wrong Password", color: .systemRed)
        }
        return cell
    }

    private func styleAction(_ cell: UITableViewCell, _ text: String, color: UIColor) {
        cell.textLabel?.text = text
        cell.textLabel?.textColor = color
        cell.textLabel?.textAlignment = .center
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .info: break
        case .password, .copy: copyPassword()
        case .join: join()
        case .directions: openDirections()
        case .report: confirmReport()
        }
    }

    // MARK: - Actions

    private func copyPassword() {
        UIPasteboard.general.string = network.password
        flash("Password Copied")
    }

    private func join() {
        let config: NEHotspotConfiguration
        if network.isOpen {
            config = NEHotspotConfiguration(ssid: network.ssid)
        } else {
            config = NEHotspotConfiguration(ssid: network.ssid, passphrase: network.password, isWEP: network.security == "WEP")
        }
        NEHotspotConfigurationManager.shared.apply(config) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let error = error as NSError? else {
                    self.showAlert(title: "Joined \"\(self.network.ssid)\"")
                    return
                }
                if error.domain == NEHotspotConfigurationErrorDomain {
                    if error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        self.showAlert(title: "Already connected to \"\(self.network.ssid)\"")
                        return
                    }
                    if error.code == NEHotspotConfigurationError.userDenied.rawValue { return }
                }
                if !self.network.isOpen { UIPasteboard.general.string = self.network.password }
                self.showAlert(
                    title: "Couldn't Join Automatically",
                    message: self.network.isOpen
                        ? "Open Settings › Wi-Fi and choose \"\(self.network.ssid)\"."
                        : "The password was copied. Open Settings › Wi-Fi, choose \"\(self.network.ssid)\" and paste it.")
            }
        }
    }

    private func openDirections() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: network.coordinate))
        item.name = network.venue.isEmpty ? network.ssid : network.venue
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func confirmReport() {
        let sheet = UIAlertController(
            title: "Report \"\(network.ssid)\"?",
            message: "Use this if the password doesn't work or the network shouldn't be shared. Your GitHub name is attached.",
            preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in self?.sendReport() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func sendReport() {
        let payload: [String: Any] = [
            "action": "report",
            "id": network.id,
            "lat": network.lat,
            "lon": network.lon
        ]
        submitToMiFi(payload: payload, title: "[MiFi] report: \(network.ssid)") { [weak self] result in
            if result == .sent { self?.showAlert(title: "Thanks", message: "Your report was sent.") }
        }
    }
}
