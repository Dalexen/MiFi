import UIKit

final class SettingsViewController: UITableViewController {
    private enum Row {
        case account
        case link(String, URL)
        case version
    }

    private var sections: [(header: String?, footer: String?, rows: [Row])] = []

    init() { super.init(style: .grouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        sections = [
            ("GitHub", "Signing in lets MiFi share networks and send reports for you. MiFi's database is the public data/ folder of the \(Config.owner)/\(Config.repo) repository.", [.account]),
            ("About", nil, [
                .link("How MiFi Works", Config.repoURL),
                .link("Browse the Database", Config.repoURL.appendingPathComponent("tree/\(Config.branch)/data/tiles")),
                .version
            ])
        ]
    }

    private var signedIn: Bool { GitHubClient.isSignedIn }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].header }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section].footer }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .account:
            if signedIn {
                cell.textLabel?.text = "Sign Out"
                cell.textLabel?.textColor = .systemRed
            } else if Config.clientID.isEmpty {
                cell.textLabel?.text = "Sign-in Not Configured"
                cell.textLabel?.textColor = .secondaryLabel
                cell.detailTextLabel?.text = "Uses Safari"
                cell.selectionStyle = .none
            } else {
                cell.textLabel?.text = "Sign in with GitHub"
                cell.textLabel?.textColor = .systemBlue
            }
        case .link(let title, _):
            cell.textLabel?.text = title
            cell.accessoryType = .disclosureIndicator
        case .version:
            let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = v
            cell.selectionStyle = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .account:
            if signedIn {
                GitHubClient.signOut()
                tableView.reloadData()
            } else if !Config.clientID.isEmpty {
                DeviceFlow.shared.start(from: self) { [weak self] _ in self?.tableView.reloadData() }
            }
        case .link(_, let url):
            UIApplication.shared.open(url)
        case .version:
            break
        }
    }
}
