import AppKit

/// Helpers for the one-time "set AutoBrowser as the system default browser"
/// step. macOS shows a single confirmation dialog; after that, every link
/// from any app lands in AutoBrowser and gets routed silently.
enum DefaultBrowser {
    static var isAutoBrowserDefault: Bool {
        guard let probe = URL(string: "http://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return handler.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    static func makeAutoBrowserDefault(completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            do {
                try await NSWorkspace.shared.setDefaultApplication(
                    at: Bundle.main.bundleURL,
                    toOpenURLsWithScheme: "http"
                )
                completion(nil)
            } catch {
                // The user declining the system dialog also lands here; that
                // is not worth an error alert.
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                    completion(nil)
                } else {
                    completion(error)
                }
            }
        }
    }
}
