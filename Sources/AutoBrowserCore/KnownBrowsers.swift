import Foundation

public enum KnownBrowsers {
    /// Well-known browsers, used only to order menus and tie-break resolution.
    /// Discovery itself is dynamic — anything registered for http(s) shows up.
    public static let preferredOrder: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",  // Arc
        "company.thebrowser.dia",      // Dia
        "net.imput.helium",            // Helium
        "org.mozilla.firefox",
        "app.zen-browser.zen",         // Zen
        "com.brave.Browser",
        "com.microsoft.edgemac",       // Microsoft Edge
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS",          // Orion
        "org.mozilla.librewolf",
        "com.sigmaos.sigmaos.macos",   // SigmaOS
        "ai.perplexity.comet",         // Comet
        "org.torproject.torbrowser",
        "org.chromium.Chromium",
    ]

    /// Sort key: known browsers first (in the order above), then everything
    /// else alphabetically by display name.
    public static func sortKey(bundleID: String, displayName: String) -> (Int, String) {
        let rank = preferredOrder.firstIndex(of: bundleID) ?? preferredOrder.count
        return (rank, displayName.lowercased())
    }
}
