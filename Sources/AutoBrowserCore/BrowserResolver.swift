import Foundation

public enum RoutingMode: String, Sendable {
    case automatic
    case manual
}

public struct ResolutionInput: Sendable {
    public var mode: RoutingMode
    public var manualBrowserID: String?
    /// Bundle IDs of browsers currently running, in preferred order.
    public var runningBrowserIDs: [String]
    /// Bundle ID of the browser the user most recently brought to the front.
    public var lastActiveBrowserID: String?
    /// Bundle IDs of all installed browsers, in preferred order.
    public var installedBrowserIDs: [String]

    public init(
        mode: RoutingMode,
        manualBrowserID: String?,
        runningBrowserIDs: [String],
        lastActiveBrowserID: String?,
        installedBrowserIDs: [String]
    ) {
        self.mode = mode
        self.manualBrowserID = manualBrowserID
        self.runningBrowserIDs = runningBrowserIDs
        self.lastActiveBrowserID = lastActiveBrowserID
        self.installedBrowserIDs = installedBrowserIDs
    }
}

public enum BrowserResolver {
    /// Decides which browser should receive a URL. Returns a bundle ID from
    /// `installedBrowserIDs`, or nil when no browser is installed at all.
    public static func resolve(_ input: ResolutionInput) -> String? {
        let installed = input.installedBrowserIDs
        let running = installed.filter(input.runningBrowserIDs.contains)

        if input.mode == .manual,
           let manual = input.manualBrowserID,
           installed.contains(manual) {
            return manual
        }

        if let last = input.lastActiveBrowserID, running.contains(last) {
            return last
        }
        if let first = running.first {
            return first
        }
        if let last = input.lastActiveBrowserID, installed.contains(last) {
            return last
        }
        return installed.first
    }
}
