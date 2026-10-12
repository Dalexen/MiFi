import Foundation

enum Config {
    static let owner = "dalexen"
    static let repo = "mifi"
    static let branch = "main"

    static var repoURL: URL { URL(string: "https://github.com/\(owner)/\(repo)")! }
    static var tileBaseURL: String { "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/data/tiles/" }

    /// OAuth App client ID used for GitHub's device-flow sign-in (injected at build time).
    /// Empty means sign-in is unavailable and submissions fall back to Safari.
    static var clientID: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MiFiGitHubClientID") as? String ?? ""
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let tokenKey = "github_token"
    static let loginKey = "github_login"
}
