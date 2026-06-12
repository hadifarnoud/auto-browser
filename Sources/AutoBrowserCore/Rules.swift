import Foundation

/// A time-of-day window in minutes since midnight. `end` is exclusive; a
/// window whose end is before its start crosses midnight (22:00–06:00).
/// Equal start and end means the whole day.
public struct TimeRange: Codable, Equatable, Sendable {
    public var startMinutes: Int
    public var endMinutes: Int

    public init(startMinutes: Int, endMinutes: Int) {
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    public func contains(_ minutesSinceMidnight: Int) -> Bool {
        if startMinutes == endMinutes { return true }
        if startMinutes < endMinutes {
            return minutesSinceMidnight >= startMinutes && minutesSinceMidnight < endMinutes
        }
        return minutesSinceMidnight >= startMinutes || minutesSinceMidnight < endMinutes
    }
}

/// A routing rule. All present conditions must hold (AND); a rule with no
/// conditions always matches. Rules are evaluated in order, first match wins,
/// and take precedence over both manual and automatic mode.
public struct BrowserRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    /// Regex matched (case-insensitively, anywhere) against the full URL.
    public var urlRegex: String?
    public var timeRange: TimeRange?
    /// Rule only applies while this browser is running.
    public var requiredOpenBrowserID: String?
    public var targetBrowserID: String

    public init(
        id: UUID = UUID(),
        name: String = "",
        isEnabled: Bool = true,
        urlRegex: String? = nil,
        timeRange: TimeRange? = nil,
        requiredOpenBrowserID: String? = nil,
        targetBrowserID: String
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.urlRegex = urlRegex
        self.timeRange = timeRange
        self.requiredOpenBrowserID = requiredOpenBrowserID
        self.targetBrowserID = targetBrowserID
    }
}

public enum RuleEvaluator {
    /// First enabled rule whose conditions all hold and whose target browser
    /// is available. Rules with invalid regexes are skipped.
    public static func firstMatch(
        rules: [BrowserRule],
        urlString: String,
        minutesSinceMidnight: Int,
        runningAppIDs: Set<String>,
        availableBrowserIDs: [String]
    ) -> BrowserRule? {
        rules.first { rule in
            guard rule.isEnabled,
                  availableBrowserIDs.contains(rule.targetBrowserID) else { return false }

            if let pattern = rule.urlRegex, !pattern.isEmpty {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                      regex.firstMatch(
                        in: urlString,
                        range: NSRange(urlString.startIndex..., in: urlString)
                      ) != nil else { return false }
            }
            if let timeRange = rule.timeRange,
               !timeRange.contains(minutesSinceMidnight) { return false }
            if let required = rule.requiredOpenBrowserID,
               !runningAppIDs.contains(required) { return false }
            return true
        }
    }
}
