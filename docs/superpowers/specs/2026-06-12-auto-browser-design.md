# AutoBrowser — Design

**Date:** 2026-06-12
**Status:** Implemented autonomously; key decision flagged for user review.

## Problem

Clicking a link in another app (Telegram, Mail, Slack…) always opens the system
default browser, even when a different browser is the one currently in use.
The user wants links to open in whichever browser is currently open, with a
menu-bar control to override manually.

## Key decision: URL router, not default-browser flipping

Two possible architectures:

1. **Flip the system default** whenever a browser launches/activates
   (`LSSetDefaultHandlerForURLScheme` / `NSWorkspace.setDefaultApplication`).
   Rejected: since macOS 12.3 every programmatic change of the default browser
   triggers a system confirmation dialog. Auto-switching would show a dialog on
   every switch. There is no sanctioned way to suppress it.

2. **Become the default browser once and route** (chosen). AutoBrowser
   registers as a handler for `http`/`https`. The user sets it as the system
   default browser one time (one confirmation dialog). From then on, every
   link clicked in any app is handed to AutoBrowser, which instantly forwards
   it to the right real browser. No dialogs, no polling, instant. This is the
   architecture used by Velja, Finicky, Choosy, and Browserosaurus.

## Behavior

- **Automatic mode (default):** route to the most recently *activated* browser
  that is still running. If no browser is running, launch the last-used
  browser. The app tracks activations via
  `NSWorkspace.didActivateApplicationNotification`.
- **Manual mode:** the user picks a browser in the menu; all links go there
  until they switch back to Automatic.
- **Browser discovery is dynamic:** `NSWorkspace.urlsForApplications(toOpen:)`
  for an `https` URL returns every installed app registered as an http(s)
  handler — Chrome, Safari, Firefox, Helium, Arc, Dia, Zen, Brave, Edge,
  Opera, Vivaldi, Orion, Tor, and anything installed later, with no hardcoded
  list required. A known-browser ordering keeps the menu tidy. AutoBrowser
  excludes itself from the list.

## UI (menu bar)

- Status item shows the icon of the browser links currently route to;
  updates live as the user switches browsers.
- Menu:
  - `Automatic (currently <Browser>)` — radio with manual entries
  - One entry per installed browser (manual override)
  - `Edit Browser List` submenu — every discovered http(s) handler with a
    check toggle. Unchecking hides false positives (download managers and
    other non-browsers that register for http) from the menu *and* from
    automatic routing. Hiding the manually selected browser reverts to
    automatic mode. Persisted in `hiddenBrowserIDs`.
  - `Make AutoBrowser the default browser…` (hidden once it is the default)
  - `Launch at Login` toggle (`SMAppService`)
  - `Quit`
- `LSUIElement` — no Dock icon.

## Components

| Unit | Responsibility | Depends on |
|---|---|---|
| `AutoBrowserCore` (library) | Pure routing decision (`BrowserResolver`), known-browser ordering | Foundation only |
| `BrowserRegistry` | Discover installed browsers, names, icons | AppKit |
| `BrowserTracker` | Track running browsers + most recently active one; persist last-active | AppKit, Registry |
| `Router` | Resolve target via Core, open URLs with `NSWorkspace.open(_:withApplicationAt:)` | Registry, Tracker, Core |
| `MenuController` | Status item + menu, mode switching, default-browser & login-item actions | all of the above |
| `AppDelegate` | Receives URLs via `application(_:open:)`, wires everything | all |

## Rules (added 2026-06-12, second iteration)

A rule routes matching links to a specific browser, taking precedence over
both manual and automatic mode. Conditions (all present ones must hold, AND):

- **URL regex** — matched case-insensitively anywhere in the absolute URL.
  Invalid patterns skip the rule rather than failing.
- **Time of day** — minutes-since-midnight window, end exclusive; end before
  start crosses midnight; equal start/end means all day.
- **Required open browser** — rule applies only while that browser runs.

Evaluation is first-match-wins over an ordered list (`RuleEvaluator` in
`AutoBrowserCore`, fully unit-tested). Each URL in a batch is evaluated
independently and opens are grouped per target. Rule targets resolve against
*all* discovered handlers (explicit intent overrides the hidden list).
A rule with no conditions always matches (acts as a pin).

Rules persist as JSON at `~/Library/Application Support/AutoBrowser/rules.json`
(`RulesStore`, debounced autosave). Edited in a native SwiftUI window
(`RulesEditor`) opened from the menu: per-rule enable toggle, name, regex
field, hour/minute pickers, browser popups, drag to reorder, delete.

## CI / Release

`.github/workflows/ci.yml` — push/PR: `swift test` + bundle build + artifact.
`.github/workflows/release.yml` — `v*` tag: test, build, zip (`ditto`),
`gh release create` with the job's ephemeral token. Only first-party
`actions/*` are used (no third-party actions to SHA-pin); permissions are
`contents: read` for CI and `contents: write` for release only.

## Resolution rules (pure, unit-tested)

1. Manual mode and the chosen browser is still installed → use it.
2. Otherwise, last-activated browser if still running.
3. Otherwise, any running browser (preferred order).
4. Otherwise, last-activated browser even if not running (launch it).
5. Otherwise, first installed browser.
6. Otherwise (no browsers at all): nil — caller logs and beeps.

## Packaging

Swift Package Manager (no Xcode project). `build.sh` compiles the release
binary, assembles `dist/AutoBrowser.app` with a hand-written `Info.plist`
(`CFBundleURLTypes` http/https + `public.html` document type so macOS lists it
as a browser), ad-hoc codesigns, and registers with Launch Services.
Minimum macOS 13.

## Error handling

- No browsers found: log + beep (practically impossible — Safari is always present).
- `SMAppService` / `setDefaultApplication` failures: alert with error text.
- Never routes to itself (registry excludes own bundle ID → no loops).

## Testing

`AutoBrowserCore` resolution logic is covered by XCTest unit tests
(manual mode, fallthroughs, empty sets). AppKit layer verified by building
and launching the bundle.
