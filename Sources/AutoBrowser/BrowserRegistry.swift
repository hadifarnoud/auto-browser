import AppKit
import AutoBrowserCore

struct Browser {
    let bundleID: String
    let name: String
    let url: URL

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Discovers installed browsers: every app registered as a handler for https
/// URLs, excluding AutoBrowser itself. No hardcoded list — new browsers show
/// up automatically; `KnownBrowsers` only provides ordering.
final class BrowserRegistry {
    private let settings: Settings

    /// Everything discovered, including apps the user has hidden.
    private(set) var allHandlers: [Browser] = []

    /// Discovered handlers minus user-hidden false positives.
    var browsers: [Browser] {
        allHandlers.filter { !settings.hiddenBrowserIDs.contains($0.bundleID) }
    }

    var bundleIDs: [String] { browsers.map(\.bundleID) }

    init(settings: Settings) {
        self.settings = settings
        refresh()
    }

    func refresh() {
        let probe = URL(string: "https://example.com")!
        let selfID = Bundle.main.bundleIdentifier

        var seen: [String: Browser] = [:]
        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != selfID else { continue }

            let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? appURL.deletingPathExtension().lastPathComponent
            let browser = Browser(bundleID: bundleID, name: name, url: appURL)

            // Prefer the /Applications copy when an app exists in two places.
            if let existing = seen[bundleID] {
                if !existing.url.path.hasPrefix("/Applications"),
                   appURL.path.hasPrefix("/Applications") {
                    seen[bundleID] = browser
                }
            } else {
                seen[bundleID] = browser
            }
        }

        allHandlers = seen.values.sorted {
            KnownBrowsers.sortKey(bundleID: $0.bundleID, displayName: $0.name)
                < KnownBrowsers.sortKey(bundleID: $1.bundleID, displayName: $1.name)
        }
    }

    func browser(withID bundleID: String?) -> Browser? {
        guard let bundleID else { return nil }
        return browsers.first { $0.bundleID == bundleID }
    }
}
