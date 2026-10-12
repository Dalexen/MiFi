import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        Theme.apply(to: window)

        let tabs = UITabBarController()
        tabs.viewControllers = [
            Theme.navigation(NearbyViewController(), title: "Nearby", symbol: "wifi"),
            Theme.navigation(MapViewController(), title: "Map", symbol: "map"),
            Theme.navigation(SettingsViewController(), title: "Settings", symbol: "gear")
        ]
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        self.window = window

        _ = NetworkStore.shared
        LocationService.shared.start()
        return true
    }
}
