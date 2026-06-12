import AppKit
import AutoBrowserCore

/// Resolves the target browser and forwards URLs to it.
final class Router {
    private let registry: BrowserRegistry
    private let tracker: BrowserTracker
    private let settings: Settings

    init(registry: BrowserRegistry, tracker: BrowserTracker, settings: Settings) {
        self.registry = registry
        self.tracker = tracker
        self.settings = settings
    }

    /// The browser links would open in right now.
    func currentTarget() -> Browser? {
        let resolved = BrowserResolver.resolve(ResolutionInput(
            mode: settings.mode,
            manualBrowserID: settings.manualBrowserID,
            runningBrowserIDs: tracker.runningBrowserIDs,
            lastActiveBrowserID: tracker.lastActiveBrowserID,
            installedBrowserIDs: registry.bundleIDs
        ))
        return registry.browser(withID: resolved)
    }

    func open(_ urls: [URL]) {
        // Browsers may have been installed or removed since launch.
        registry.refresh()

        guard let target = currentTarget() else {
            NSLog("AutoBrowser: no browser available to open \(urls)")
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(
            urls,
            withApplicationAt: target.url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                NSLog("AutoBrowser: failed to open in \(target.name): \(error.localizedDescription)")
            }
        }
    }
}
