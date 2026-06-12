import XCTest
@testable import AutoBrowserCore

final class RuleEvaluatorTests: XCTestCase {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let helium = "net.imput.helium"

    private func match(
        rules: [BrowserRule],
        url: String = "https://example.com/page",
        minutes: Int = 12 * 60,
        running: Set<String> = [],
        available: [String]? = nil
    ) -> BrowserRule? {
        RuleEvaluator.firstMatch(
            rules: rules,
            urlString: url,
            minutesSinceMidnight: minutes,
            runningAppIDs: running,
            availableBrowserIDs: available ?? [safari, chrome, helium]
        )
    }

    // MARK: URL regex

    func testURLRegexMatches() {
        let rule = BrowserRule(urlRegex: #"github\.com"#, targetBrowserID: chrome)
        XCTAssertEqual(match(rules: [rule], url: "https://github.com/owner/repo")?.id, rule.id)
        XCTAssertNil(match(rules: [rule], url: "https://gitlab.com/x"))
    }

    func testURLRegexIsCaseInsensitive() {
        let rule = BrowserRule(urlRegex: "GitHub", targetBrowserID: chrome)
        XCTAssertNotNil(match(rules: [rule], url: "https://github.com"))
    }

    func testInvalidRegexSkipsRule() {
        let bad = BrowserRule(urlRegex: "([unclosed", targetBrowserID: chrome)
        let good = BrowserRule(urlRegex: "example", targetBrowserID: helium)
        XCTAssertEqual(match(rules: [bad, good])?.targetBrowserID, helium)
    }

    func testEmptyRegexStringIsTreatedAsNoURLCondition() {
        let rule = BrowserRule(urlRegex: "", targetBrowserID: chrome)
        XCTAssertNotNil(match(rules: [rule]))
    }

    // MARK: Time of day

    func testTimeRangeWithinDay() {
        let work = BrowserRule(
            timeRange: TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60),
            targetBrowserID: chrome
        )
        XCTAssertNotNil(match(rules: [work], minutes: 12 * 60))
        XCTAssertNil(match(rules: [work], minutes: 20 * 60))
        XCTAssertNil(match(rules: [work], minutes: 17 * 60)) // end exclusive
        XCTAssertNotNil(match(rules: [work], minutes: 9 * 60)) // start inclusive
    }

    func testTimeRangeCrossingMidnight() {
        let night = BrowserRule(
            timeRange: TimeRange(startMinutes: 22 * 60, endMinutes: 6 * 60),
            targetBrowserID: helium
        )
        XCTAssertNotNil(match(rules: [night], minutes: 23 * 60))
        XCTAssertNotNil(match(rules: [night], minutes: 2 * 60))
        XCTAssertNil(match(rules: [night], minutes: 12 * 60))
    }

    func testEqualStartAndEndMeansAllDay() {
        XCTAssertTrue(TimeRange(startMinutes: 300, endMinutes: 300).contains(0))
        XCTAssertTrue(TimeRange(startMinutes: 300, endMinutes: 300).contains(1439))
    }

    // MARK: Required open browser

    func testRequiredBrowserMustBeRunning() {
        let rule = BrowserRule(requiredOpenBrowserID: helium, targetBrowserID: helium)
        XCTAssertNotNil(match(rules: [rule], running: [helium, "com.apple.dt.Xcode"]))
        XCTAssertNil(match(rules: [rule], running: [chrome]))
    }

    // MARK: Combined conditions and ordering

    func testAllConditionsMustHold() {
        let rule = BrowserRule(
            urlRegex: "example",
            timeRange: TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60),
            requiredOpenBrowserID: chrome,
            targetBrowserID: chrome
        )
        XCTAssertNotNil(match(rules: [rule], minutes: 10 * 60, running: [chrome]))
        XCTAssertNil(match(rules: [rule], minutes: 10 * 60, running: []))
        XCTAssertNil(match(rules: [rule], minutes: 20 * 60, running: [chrome]))
        XCTAssertNil(match(rules: [rule], url: "https://other.org", minutes: 10 * 60, running: [chrome]))
    }

    func testFirstMatchWins() {
        let first = BrowserRule(urlRegex: "example", targetBrowserID: safari)
        let second = BrowserRule(urlRegex: "example", targetBrowserID: chrome)
        XCTAssertEqual(match(rules: [first, second])?.targetBrowserID, safari)
    }

    func testDisabledRuleIsSkipped() {
        let disabled = BrowserRule(isEnabled: false, urlRegex: "example", targetBrowserID: safari)
        let enabled = BrowserRule(urlRegex: "example", targetBrowserID: chrome)
        XCTAssertEqual(match(rules: [disabled, enabled])?.targetBrowserID, chrome)
    }

    func testRuleWithUnavailableTargetIsSkipped() {
        let gone = BrowserRule(urlRegex: "example", targetBrowserID: "com.uninstalled.browser")
        XCTAssertNil(match(rules: [gone]))
    }

    func testRuleWithNoConditionsAlwaysMatches() {
        let pin = BrowserRule(targetBrowserID: helium)
        XCTAssertEqual(match(rules: [pin])?.targetBrowserID, helium)
    }

    func testNoRulesReturnsNil() {
        XCTAssertNil(match(rules: []))
    }
}
