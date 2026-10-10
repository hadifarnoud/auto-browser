import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var registry: BrowserRegistry!
    private var tracker: BrowserTracker!
    private var router: Router!
    private var rulesStore: RulesStore!
    private var menuController: MenuController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings.shared
        registry = BrowserRegistry(settings: settings)
        tracker = BrowserTracker(registry: registry, settings: settings)
        rulesStore = RulesStore()
        router = Router(registry: registry, tracker: tracker, settings: settings, rulesStore: rulesStore)
        menuController = MenuController(
            registry: registry,
            tracker: tracker,
            router: router,
            settings: settings,
            rulesStore: rulesStore
        )
    }

    /// Entry point for every link clicked anywhere in the system once
    /// AutoBrowser is the default browser. AppKit buffers URLs that arrive
    /// during launch and delivers them here after launching finishes.
    func application(_ application: NSApplication, open urls: [URL]) {
        router.open(urls)
    }

    /// Login launches keep the saved visibility; opening the app explicitly
    /// restores its controls without changing link routing.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let launchReason = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        if launchReason != keyAELaunchedAsLogInItem {
            restoreMenuBarIcon()
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        restoreMenuBarIcon()
        return false
    }

    private func restoreMenuBarIcon() {
        // The initial open event can arrive before the menu is constructed.
        Settings.shared.menuBarHidden = false
        menuController?.showMenuBarIcon()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
