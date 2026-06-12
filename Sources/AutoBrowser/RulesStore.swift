import Combine
import Foundation
import AutoBrowserCore

/// Loads and persists rules as JSON in Application Support, so they survive
/// reinstalls and can be hand-edited or backed up.
final class RulesStore: ObservableObject {
    @Published var rules: [BrowserRule] = []

    private let fileURL: URL
    private var saveCancellable: AnyCancellable?

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        fileURL = appSupport
            .appendingPathComponent("AutoBrowser", isDirectory: true)
            .appendingPathComponent("rules.json")

        load()

        saveCancellable = $rules
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.save() }
    }

    var activeRuleCount: Int {
        rules.filter(\.isEnabled).count
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([BrowserRule].self, from: data) else { return }
        rules = loaded
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rules).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("AutoBrowser: failed to save rules: \(error.localizedDescription)")
        }
    }
}
