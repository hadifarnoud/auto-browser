import Foundation
import AutoBrowserCore

/// UserDefaults-backed preferences.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let mode = "routingMode"
        static let manualBrowserID = "manualBrowserID"
        static let lastActiveBrowserID = "lastActiveBrowserID"
        static let hiddenBrowserIDs = "hiddenBrowserIDs"
        static let menuBarHidden = "menuBarHidden"
    }

    var mode: RoutingMode {
        get { defaults.string(forKey: Key.mode).flatMap(RoutingMode.init) ?? .automatic }
        set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    var manualBrowserID: String? {
        get { defaults.string(forKey: Key.manualBrowserID) }
        set { defaults.set(newValue, forKey: Key.manualBrowserID) }
    }

    /// Stay hidden across background launches until the app is explicitly opened.
    var menuBarHidden: Bool {
        get { defaults.bool(forKey: Key.menuBarHidden) }
        set { defaults.set(newValue, forKey: Key.menuBarHidden) }
    }

    /// Persisted so "no browser running" still routes to the last one used,
    /// even across restarts of AutoBrowser.
    var lastActiveBrowserID: String? {
        get { defaults.string(forKey: Key.lastActiveBrowserID) }
        set { defaults.set(newValue, forKey: Key.lastActiveBrowserID) }
    }

    /// Apps that register as http(s) handlers but aren't really browsers
    /// (download managers etc.) — excluded from the menu and from routing.
    var hiddenBrowserIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.hiddenBrowserIDs) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: Key.hiddenBrowserIDs) }
    }
}
