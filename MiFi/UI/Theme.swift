import UIKit

/// Classic iOS 11–14 look: opaque-ish grouped lists, large titles, blue tint, no glass.
enum Theme {
    static func apply(to window: UIWindow) {
        window.tintColor = .systemBlue

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()

        let largeTitleEdge = UINavigationBarAppearance()
        largeTitleEdge.configureWithOpaqueBackground()
        largeTitleEdge.backgroundColor = .systemGroupedBackground
        largeTitleEdge.shadowColor = .clear

        let nav = UINavigationBar.appearance()
        nav.standardAppearance = standard
        nav.compactAppearance = standard
        nav.scrollEdgeAppearance = largeTitleEdge

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // iOS 15 added extra padding above section headers; iOS 11–14 had none.
        UITableView.appearance().sectionHeaderTopPadding = 0
    }

    static func navigation(_ root: UIViewController, title: String, symbol: String) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: nil)
        return nav
    }
}

extension UIViewController {
    func showAlert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Brief confirmation, like the old "Copied" HUD.
    func flash(_ text: String) {
        let alert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { alert.dismiss(animated: true) }
    }

    @objc func presentAddNetwork() {
        let nav = UINavigationController(rootViewController: AddNetworkViewController())
        present(nav, animated: true)
    }
}
