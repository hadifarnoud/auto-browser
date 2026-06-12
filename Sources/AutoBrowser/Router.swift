import AppKit
import AutoBrowserCore

/// Resolves the target browser and forwards URLs to it.
final class Router {
    private let registry: BrowserRegistry
    private let tracker: BrowserTracker
    private let settings: Settings
    private let rulesStore: RulesStore

    init(registry: BrowserRegistry, tracker: BrowserTracker, settings: Settings, rulesStore: RulesStore) {
        self.registry = registry
        self.tracker = tracker
        self.settings = settings
        self.rulesStore = rulesStore
    }

    /// The browser non-rule links would open in right now.
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

        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let runningAppIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        // Rule targets may name a browser the user hid from the main list —
        // an explicit rule is explicit intent, so resolve against everything.
        let availableIDs = registry.allHandlers.map(\.bundleID)

        var ruleRouted: [String: [URL]] = [:]
        var defaultRouted: [URL] = []
        for url in urls {
            if let rule = RuleEvaluator.firstMatch(
                rules: rulesStore.rules,
                urlString: url.absoluteString,
                minutesSinceMidnight: minutes,
                runningAppIDs: runningAppIDs,
                availableBrowserIDs: availableIDs
            ) {
                ruleRouted[rule.targetBrowserID, default: []].append(url)
            } else {
                defaultRouted.append(url)
            }
        }

        for (bundleID, urls) in ruleRouted {
            if let browser = registry.allHandlers.first(where: { $0.bundleID == bundleID }) {
                open(urls, in: browser)
            }
        }
        if !defaultRouted.isEmpty {
            guard let target = currentTarget() else {
                NSLog("AutoBrowser: no browser available to open \(defaultRouted)")
                NSSound.beep()
                return
            }
            open(defaultRouted, in: target)
        }
    }

    private func open(_ urls: [URL], in browser: Browser) {
        NSWorkspace.shared.open(
            urls,
            withApplicationAt: browser.url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                NSLog("AutoBrowser: failed to open in \(browser.name): \(error.localizedDescription)")
            }
        }
    }
}
