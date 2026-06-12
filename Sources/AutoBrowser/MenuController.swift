import AppKit
import AutoBrowserCore
import ServiceManagement

/// Owns the status item and menu. The status icon mirrors the browser links
/// currently route to, updating live as the user switches browsers.
final class MenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let registry: BrowserRegistry
    private let tracker: BrowserTracker
    private let router: Router
    private let settings: Settings

    init(registry: BrowserRegistry, tracker: BrowserTracker, router: Router, settings: Settings) {
        self.registry = registry
        self.tracker = tracker
        self.router = router
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        tracker.onChange = { [weak self] in self?.updateStatusIcon() }
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        if let target = router.currentTarget() {
            let icon = target.icon
            icon.size = NSSize(width: 19, height: 19)
            button.image = icon
            button.toolTip = toolTipText(for: target)
        } else {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "AutoBrowser")
            button.toolTip = "AutoBrowser"
        }
    }

    private func toolTipText(for target: Browser) -> String {
        switch settings.mode {
        case .automatic: return "AutoBrowser — links open in \(target.name) (automatic)"
        case .manual: return "AutoBrowser — links open in \(target.name) (manual)"
        }
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        registry.refresh()
        menu.removeAllItems()

        let targetName = router.currentTarget()?.name ?? "—"
        let auto = NSMenuItem(
            title: "Automatic (currently \(targetName))",
            action: #selector(selectAutomatic),
            keyEquivalent: ""
        )
        auto.target = self
        auto.state = settings.mode == .automatic ? .on : .off
        menu.addItem(auto)

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Always Use"))

        for browser in registry.browsers {
            let item = NSMenuItem(title: browser.name, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser.bundleID
            let icon = browser.icon
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            item.state = (settings.mode == .manual && settings.manualBrowserID == browser.bundleID) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(editBrowserListItem())
        menu.addItem(.separator())

        if DefaultBrowser.isAutoBrowserDefault {
            let item = NSMenuItem(title: "AutoBrowser is the default browser ✓", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let item = NSMenuItem(
                title: "Make AutoBrowser the Default Browser…",
                action: #selector(makeDefault),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
        }

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit AutoBrowser", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    /// Submenu listing every discovered http(s) handler with a check toggle,
    /// so false positives (download managers etc.) can be removed from the
    /// browser list — and from automatic routing.
    private func editBrowserListItem() -> NSMenuItem {
        let submenu = NSMenu()
        let hidden = settings.hiddenBrowserIDs
        for handler in registry.allHandlers {
            let item = NSMenuItem(
                title: handler.name,
                action: #selector(toggleBrowserVisibility(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = handler.bundleID
            let icon = handler.icon
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            item.state = hidden.contains(handler.bundleID) ? .off : .on
            submenu.addItem(item)
        }

        let parent = NSMenuItem(title: "Edit Browser List", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: Actions

    @objc private func selectAutomatic() {
        settings.mode = .automatic
        updateStatusIcon()
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        settings.mode = .manual
        settings.manualBrowserID = bundleID
        updateStatusIcon()
    }

    @objc private func toggleBrowserVisibility(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        var hidden = settings.hiddenBrowserIDs
        if hidden.contains(bundleID) {
            hidden.remove(bundleID)
        } else {
            hidden.insert(bundleID)
        }
        settings.hiddenBrowserIDs = hidden

        // Hiding the manually selected browser reverts to automatic mode.
        if settings.mode == .manual,
           let manual = settings.manualBrowserID,
           hidden.contains(manual) {
            settings.mode = .automatic
        }
        updateStatusIcon()
    }

    @objc private func makeDefault() {
        DefaultBrowser.makeAutoBrowserDefault { error in
            if let error {
                let alert = NSAlert()
                alert.messageText = "Could not change the default browser"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
