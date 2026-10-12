import UIKit

final class TextFieldCell: UITableViewCell {
    let field = UITextField()

    init(title: String, placeholder: String) {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none

        let label = UILabel()
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)

        field.placeholder = placeholder
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .next
        field.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(label)
        contentView.addSubview(field)
        let m = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            label.widthAnchor.constraint(equalToConstant: 84),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            field.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            field.topAnchor.constraint(equalTo: contentView.topAnchor),
            field.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SegmentCell: UITableViewCell {
    let control: UISegmentedControl

    init(items: [String]) {
        control = UISegmentedControl(items: items)
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(control)
        let m = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            control.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            control.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class AddNetworkViewController: UITableViewController, UITextFieldDelegate {
    private let securityOptions = ["WPA2", "WPA3", "WEP", "Open"]

    private let ssidCell = TextFieldCell(title: "Name", placeholder: "Network name")
    private let passwordCell = TextFieldCell(title: "Password", placeholder: "Required")
    private let venueCell = TextFieldCell(title: "Place", placeholder: "Café, library… (optional)")
    private let securityCell = SegmentCell(items: ["WPA2", "WPA3", "WEP", "Open"])
    private let locationCell = UITableViewCell(style: .value1, reuseIdentifier: nil)
    private let permissionCell = UITableViewCell(style: .default, reuseIdentifier: nil)
    private let permissionSwitch = UISwitch()
    private lazy var shareItem = UIBarButtonItem(title: "Share", style: .done, target: self, action: #selector(submit))

    private lazy var rows: [[UITableViewCell]] = [
        [ssidCell, securityCell, passwordCell],
        [venueCell],
        [locationCell],
        [permissionCell]
    ]

    init() { super.init(style: .grouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Share Network"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = shareItem
        tableView.keyboardDismissMode = .interactive

        for cell in [ssidCell, passwordCell, venueCell] {
            cell.field.delegate = self
            cell.field.addTarget(self, action: #selector(formChanged), for: .editingChanged)
        }
        venueCell.field.returnKeyType = .done
        securityCell.control.addTarget(self, action: #selector(securityChanged), for: .valueChanged)

        locationCell.textLabel?.text = "Location"
        locationCell.selectionStyle = .none

        permissionCell.textLabel?.text = "I'm allowed to share this password"
        permissionCell.textLabel?.numberOfLines = 0
        permissionCell.selectionStyle = .none
        permissionCell.accessoryView = permissionSwitch
        permissionSwitch.addTarget(self, action: #selector(formChanged), for: .valueChanged)

        NotificationCenter.default.addObserver(self, selector: #selector(updateLocation), name: LocationService.didUpdate, object: nil)
        updateLocation()
        formChanged()
    }

    // MARK: - State

    private var security: String { securityOptions[securityCell.control.selectedSegmentIndex] }
    private var isOpen: Bool { security == "Open" }

    private func trimmed(_ cell: TextFieldCell) -> String {
        (cell.field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func updateLocation() {
        if let loc = LocationService.shared.location {
            locationCell.detailTextLabel?.text = String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
        } else {
            locationCell.detailTextLabel?.text = LocationService.shared.isDenied ? "Off" : "Locating…"
        }
        formChanged()
    }

    @objc private func securityChanged() {
        passwordCell.field.isEnabled = !isOpen
        passwordCell.field.placeholder = isOpen ? "Not needed" : "Required"
        if isOpen { passwordCell.field.text = "" }
        formChanged()
    }

    @objc private func formChanged() {
        let ssid = trimmed(ssidCell)
        let password = trimmed(passwordCell)
        let ssidOK = !ssid.isEmpty && ssid.utf8.count <= 32
        let passwordOK = isOpen || (!password.isEmpty && password.count <= 63)
        shareItem.isEnabled = ssidOK && passwordOK && permissionSwitch.isOn && LocationService.shared.location != nil
    }

    // MARK: - Actions

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func submit() {
        guard let loc = LocationService.shared.location else { return }
        view.endEditing(true)
        let ssid = trimmed(ssidCell)
        let payload: [String: Any] = [
            "action": "add",
            "ssid": ssid,
            "password": isOpen ? "" : trimmed(passwordCell),
            "security": security,
            "venue": trimmed(venueCell),
            "lat": (loc.coordinate.latitude * 1_000_000).rounded() / 1_000_000,
            "lon": (loc.coordinate.longitude * 1_000_000).rounded() / 1_000_000
        ]
        shareItem.isEnabled = false
        submitToMiFi(payload: payload, title: "[MiFi] add: \(ssid)") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .sent:
                let alert = UIAlertController(
                    title: "Thanks!",
                    message: "\"\(ssid)\" was sent. It appears for everyone after GitHub processes it, usually within a few minutes.",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss(animated: true) })
                self.present(alert, animated: true)
            case .openedInBrowser:
                self.dismiss(animated: true)
            case .failed:
                self.formChanged()
            }
        }
    }

    // MARK: - Text field

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === ssidCell.field {
            (isOpen ? venueCell : passwordCell).field.becomeFirstResponder()
        } else if textField === passwordCell.field {
            venueCell.field.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }

    // MARK: - Table view

    override func numberOfSections(in tableView: UITableView) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows[section].count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        rows[indexPath.section][indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Network" : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 2: return "The network is placed at your current location, so share it while you're there."
        case 3: return "Only share passwords that the owner makes public, such as cafés, libraries and shops that post theirs. Submissions are public and tied to your GitHub name."
        default: return nil
        }
    }
}
