import AppKit

/// Watches which browsers are running and which one the user most recently
/// brought to the front. That browser is what "currently open" means in
/// automatic mode.
final class BrowserTracker {
    private let registry: BrowserRegistry
    private let settings: Settings
    private var observer: NSObjectProtocol?

    /// Called whenever the routing target may have changed.
    var onChange: (() -> Void)?

    init(registry: BrowserRegistry, settings: Settings) {
        self.registry = registry
        self.settings = settings

        // Seed from the frontmost app if it happens to be a browser, so a
        // fresh launch routes correctly before any activation event arrives.
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           registry.bundleIDs.contains(front) {
            settings.lastActiveBrowserID = front
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  self.registry.bundleIDs.contains(bundleID) else { return }
            self.settings.lastActiveBrowserID = bundleID
            self.onChange?()
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    var lastActiveBrowserID: String? {
        settings.lastActiveBrowserID
    }

    /// Running browsers in the registry's preferred order.
    var runningBrowserIDs: [String] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return registry.bundleIDs.filter(running.contains)
    }
}
