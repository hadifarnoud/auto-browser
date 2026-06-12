import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var registry: BrowserRegistry!
    private var tracker: BrowserTracker!
    private var router: Router!
    private var menuController: MenuController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings.shared
        registry = BrowserRegistry(settings: settings)
        tracker = BrowserTracker(registry: registry, settings: settings)
        router = Router(registry: registry, tracker: tracker, settings: settings)
        menuController = MenuController(
            registry: registry,
            tracker: tracker,
            router: router,
            settings: settings
        )
    }

    /// Entry point for every link clicked anywhere in the system once
    /// AutoBrowser is the default browser. AppKit buffers URLs that arrive
    /// during launch and delivers them here after launching finishes.
    func application(_ application: NSApplication, open urls: [URL]) {
        router.open(urls)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
