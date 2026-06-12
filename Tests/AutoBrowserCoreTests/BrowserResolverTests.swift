import XCTest
@testable import AutoBrowserCore

final class BrowserResolverTests: XCTestCase {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let helium = "net.imput.helium"
    private let arc = "company.thebrowser.Browser"

    private func input(
        mode: RoutingMode = .automatic,
        manual: String? = nil,
        running: [String] = [],
        lastActive: String? = nil,
        installed: [String]
    ) -> ResolutionInput {
        ResolutionInput(
            mode: mode,
            manualBrowserID: manual,
            runningBrowserIDs: running,
            lastActiveBrowserID: lastActive,
            installedBrowserIDs: installed
        )
    }

    // MARK: Manual mode

    func testManualModeUsesChosenBrowser() {
        let result = BrowserResolver.resolve(input(
            mode: .manual, manual: helium,
            running: [safari, chrome], lastActive: chrome,
            installed: [safari, chrome, helium]
        ))
        XCTAssertEqual(result, helium)
    }

    func testManualModeWithUninstalledChoiceFallsThroughToAutomatic() {
        let result = BrowserResolver.resolve(input(
            mode: .manual, manual: arc,
            running: [chrome], lastActive: chrome,
            installed: [safari, chrome]
        ))
        XCTAssertEqual(result, chrome)
    }

    // MARK: Automatic mode

    func testAutomaticPrefersLastActiveRunningBrowser() {
        let result = BrowserResolver.resolve(input(
            running: [safari, chrome, helium], lastActive: helium,
            installed: [safari, chrome, helium]
        ))
        XCTAssertEqual(result, helium)
    }

    func testAutomaticFallsBackToAnyRunningBrowserInPreferredOrder() {
        let result = BrowserResolver.resolve(input(
            running: [chrome, helium], lastActive: arc, // arc no longer running
            installed: [safari, chrome, helium]
        ))
        XCTAssertEqual(result, chrome)
    }

    func testAutomaticLaunchesLastActiveWhenNothingIsRunning() {
        let result = BrowserResolver.resolve(input(
            running: [], lastActive: helium,
            installed: [safari, chrome, helium]
        ))
        XCTAssertEqual(result, helium)
    }

    func testAutomaticFallsBackToFirstInstalledWhenNoHistory() {
        let result = BrowserResolver.resolve(input(
            running: [], lastActive: nil,
            installed: [safari, chrome]
        ))
        XCTAssertEqual(result, safari)
    }

    func testStaleLastActiveNotInstalledIsIgnored() {
        let result = BrowserResolver.resolve(input(
            running: [], lastActive: arc, // uninstalled since
            installed: [safari, chrome]
        ))
        XCTAssertEqual(result, safari)
    }

    func testNoBrowsersInstalledReturnsNil() {
        XCTAssertNil(BrowserResolver.resolve(input(installed: [])))
    }

    func testRunningBrowserNotInInstalledListIsIgnored() {
        // e.g. a browser running from a mounted DMG that discovery didn't return
        let result = BrowserResolver.resolve(input(
            running: [arc], lastActive: arc,
            installed: [safari]
        ))
        XCTAssertEqual(result, safari)
    }
}
