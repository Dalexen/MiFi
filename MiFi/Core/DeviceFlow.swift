import UIKit

/// GitHub OAuth device flow: no client secret and no server needed.
final class DeviceFlow {
    static let shared = DeviceFlow()

    private var cancelled = false

    func start(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        let clientID = Config.clientID
        guard !clientID.isEmpty else {
            presenter.showAlert(title: "Sign-in Unavailable", message: "This build has no GitHub client ID configured.")
            completion(false)
            return
        }
        cancelled = false
        post("https://github.com/login/device/code", form: ["client_id": clientID, "scope": "public_repo"]) { [weak self] json in
            guard let self = self,
                  let json = json,
                  let deviceCode = json["device_code"] as? String,
                  let userCode = json["user_code"] as? String,
                  let uri = json["verification_uri"] as? String else {
                presenter.showAlert(title: "Sign-in Failed", message: "Couldn't reach GitHub. Check your connection and try again.")
                completion(false)
                return
            }
            let interval = json["interval"] as? Int ?? 5
            let expires = json["expires_in"] as? Int ?? 900

            let alert = UIAlertController(
                title: "Sign in with GitHub",
                message: "Enter this code on GitHub:\n\n\(userCode)\n\nMiFi will finish signing in automatically.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Copy Code & Open GitHub", style: .default) { _ in
                UIPasteboard.general.string = userCode
                if let url = URL(string: uri) { UIApplication.shared.open(url) }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.cancelled = true
                completion(false)
            })
            presenter.present(alert, animated: true)

            let deadline = Date().addingTimeInterval(TimeInterval(expires))
            self.poll(clientID: clientID, deviceCode: deviceCode, interval: interval, deadline: deadline) { token in
                if let token = token {
                    Keychain.set(token, for: Config.tokenKey)
                    if presenter.presentedViewController === alert { alert.dismiss(animated: true) }
                    completion(true)
                } else if !self.cancelled {
                    if presenter.presentedViewController === alert { alert.dismiss(animated: true) }
                    presenter.showAlert(title: "Sign-in Failed", message: "The code expired or was denied.")
                    completion(false)
                }
            }
        }
    }

    private func poll(clientID: String, deviceCode: String, interval: Int, deadline: Date, done: @escaping (String?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(interval)) { [weak self] in
            guard let self = self, !self.cancelled else { return }
            if Date() > deadline { done(nil); return }
            let form = [
                "client_id": clientID,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ]
            self.post("https://github.com/login/oauth/access_token", form: form) { json in
                if let token = json?["access_token"] as? String {
                    done(token)
                    return
                }
                switch json?["error"] as? String {
                case "authorization_pending", nil:
                    self.poll(clientID: clientID, deviceCode: deviceCode, interval: interval, deadline: deadline, done: done)
                case "slow_down":
                    self.poll(clientID: clientID, deviceCode: deviceCode, interval: interval + 5, deadline: deadline, done: done)
                default:
                    done(nil)
                }
            }
        }
    }

    private func post(_ urlString: String, form: [String: String], completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { completion(json) }
        }.resume()
    }
}
