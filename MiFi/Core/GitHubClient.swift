import UIKit

enum SubmitResult {
    case sent
    case openedInBrowser
    case failed
}

private enum ClientError: LocalizedError {
    case unauthorized
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Your GitHub sign-in expired. Please sign in again."
        case .http(let code): return "GitHub returned status \(code)."
        }
    }
}

/// "Backend" writes: the app files an issue on the MiFi repo; a GitHub Action validates it
/// and commits it into data/tiles/.
enum GitHubClient {
    static var isSignedIn: Bool { Keychain.get(Config.tokenKey) != nil }

    static func signOut() {
        Keychain.remove(Config.tokenKey)
        Keychain.remove(Config.loginKey)
    }

    static func createIssue(title: String, body: String, token: String, completion: @escaping (Error?) -> Void) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Config.owner)/\(Config.repo)/issues")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["title": title, "body": body])
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(error); return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                switch code {
                case 201: completion(nil)
                case 401: completion(ClientError.unauthorized)
                default: completion(ClientError.http(code))
                }
            }
        }.resume()
    }

    static func browserURL(title: String, body: String) -> URL? {
        var c = URLComponents(url: Config.repoURL.appendingPathComponent("issues/new"), resolvingAgainstBaseURL: false)
        c?.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "body", value: body)]
        return c?.url
    }
}

extension UIViewController {
    /// Sends an add/report payload to the MiFi backend (a GitHub issue).
    func submitToMiFi(payload: [String: Any], title: String, completion: @escaping (SubmitResult) -> Void) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            completion(.failed)
            return
        }
        let body = "```json\n\(json)\n```\n\n_Submitted from the MiFi app._"

        if let token = Keychain.get(Config.tokenKey) {
            GitHubClient.createIssue(title: title, body: body, token: token) { [weak self] error in
                if let error = error {
                    if case ClientError.unauthorized = error { GitHubClient.signOut() }
                    self?.showAlert(title: "Couldn't Submit", message: error.localizedDescription)
                    completion(.failed)
                } else {
                    completion(.sent)
                }
            }
            return
        }

        let alert = UIAlertController(
            title: "Sign in to Share",
            message: "MiFi's database lives on GitHub. Submissions are filed publicly under your GitHub account.",
            preferredStyle: .alert)
        if !Config.clientID.isEmpty {
            alert.addAction(UIAlertAction(title: "Sign in with GitHub", style: .default) { [weak self] _ in
                guard let self = self else { return }
                DeviceFlow.shared.start(from: self) { ok in
                    if ok {
                        self.submitToMiFi(payload: payload, title: title, completion: completion)
                    } else {
                        completion(.failed)
                    }
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Continue in Safari", style: .default) { _ in
            if let url = GitHubClient.browserURL(title: title, body: body) {
                UIApplication.shared.open(url)
                completion(.openedInBrowser)
            } else {
                completion(.failed)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(.failed) })
        present(alert, animated: true)
    }
}
