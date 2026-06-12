import AppKit
import SwiftUI
import AutoBrowserCore

struct BrowserOption: Identifiable {
    let id: String
    let name: String
}

/// Native editor window for routing rules. Rules are evaluated top to bottom;
/// drag to reorder. Persistence is automatic via RulesStore.
struct RulesEditorView: View {
    @ObservedObject var store: RulesStore
    let browsers: [BrowserOption]

    var body: some View {
        VStack(spacing: 0) {
            if store.rules.isEmpty {
                VStack(spacing: 6) {
                    Text("No rules yet")
                        .font(.title3)
                    Text("Rules route matching links to a specific browser, overriding both automatic and manual mode.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($store.rules) { $rule in
                        RuleRowView(rule: $rule, browsers: browsers) {
                            store.rules.removeAll { $0.id == rule.id }
                        }
                    }
                    .onMove { store.rules.move(fromOffsets: $0, toOffset: $1) }
                }
            }

            Divider()
            HStack {
                Button {
                    store.rules.append(BrowserRule(
                        name: "New Rule",
                        targetBrowserID: browsers.first?.id ?? ""
                    ))
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                Spacer()
                Text("Evaluated top to bottom — first match wins. Drag to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .frame(minWidth: 620, minHeight: 440)
    }
}

private struct RuleRowView: View {
    @Binding var rule: BrowserRule
    let browsers: [BrowserOption]
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $rule.isEnabled)
                    .labelsHidden()
                    .help("Enable or disable this rule")
                TextField("Rule name", text: $rule.name)
                    .textFieldStyle(.roundedBorder)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete this rule")
            }

            TextField("URL pattern (regex, optional) — e.g. github\\.com", text: urlRegexBinding)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())

            HStack(spacing: 8) {
                Toggle("Between", isOn: timeEnabledBinding)
                if rule.timeRange != nil {
                    DatePicker("", selection: timeBinding(\.startMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("and")
                    DatePicker("", selection: timeBinding(\.endMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("(may cross midnight)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Picker("Only while open:", selection: requiredBrowserBinding) {
                    Text("Always").tag(String?.none)
                    ForEach(browsers) { browser in
                        Text(browser.name).tag(String?.some(browser.id))
                    }
                }
                .fixedSize()

                Picker("Open in:", selection: $rule.targetBrowserID) {
                    ForEach(browsers) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .fixedSize()
            }
        }
        .padding(.vertical, 6)
        .opacity(rule.isEnabled ? 1 : 0.5)
    }

    private var urlRegexBinding: Binding<String> {
        Binding(
            get: { rule.urlRegex ?? "" },
            set: { rule.urlRegex = $0.isEmpty ? nil : $0 }
        )
    }

    private var timeEnabledBinding: Binding<Bool> {
        Binding(
            get: { rule.timeRange != nil },
            set: { rule.timeRange = $0 ? TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60) : nil }
        )
    }

    private var requiredBrowserBinding: Binding<String?> {
        Binding(
            get: { rule.requiredOpenBrowserID },
            set: { rule.requiredOpenBrowserID = $0 }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<TimeRange, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = rule.timeRange?[keyPath: keyPath] ?? 0
                return Calendar.current.date(
                    bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                rule.timeRange?[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

/// Keeps the rules window alive across opens; the menu is the only entry point.
final class RulesWindowController {
    private var window: NSWindow?
    private var hosting: NSHostingController<RulesEditorView>?

    func show(store: RulesStore, browsers: [BrowserOption]) {
        let view = RulesEditorView(store: store, browsers: browsers)
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "AutoBrowser Rules"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 660, height: 480))
            window.center()
            self.hosting = hosting
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
