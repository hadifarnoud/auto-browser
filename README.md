# AutoBrowser

A tiny native macOS menu bar app that makes links open in whichever browser
you're **currently using** — not whatever the system default happens to be.

Click a link in Telegram while Chrome is frontmost → it opens in Chrome.
Switch to Helium, click another link → it opens in Helium. No dialogs, no
fiddling with System Settings.

## How it works

macOS shows a confirmation dialog every time the default browser changes
programmatically, so an app that flips the default back and forth would nag
you constantly. AutoBrowser inverts the trick: **it becomes your default
browser once**, then instantly forwards every clicked link to the right real
browser (the same architecture used by Velja, Finicky, and Choosy).

- **Automatic mode** (default): links open in the browser you most recently
  used that is still running. If none is running, the last-used browser is
  launched.
- **Manual mode**: pick any browser in the menu; everything opens there until
  you switch back to Automatic.
- **Rules** (menu → *Rules…*): route specific links to a specific browser,
  overriding both modes. Each rule can combine three conditions (all must
  hold): a **URL regex** (e.g. `github\.com`), a **time-of-day window**
  (may cross midnight), and **only while a given browser is open**. Rules are
  evaluated top to bottom, first match wins; drag to reorder. Stored as JSON
  in `~/Library/Application Support/AutoBrowser/rules.json`.

Browsers are discovered dynamically — anything registered as an http(s)
handler shows up (Safari, Chrome, Firefox, Helium, Arc, Dia, Zen, Brave,
Edge, Opera, Vivaldi, Orion, Tor Browser, …including browsers installed
later). The menu bar icon mirrors the browser links currently route to.

Some non-browsers (download managers, etc.) also register for http(s) and
get picked up by discovery. Use **Edit Browser List** in the menu to uncheck
them — hidden apps disappear from the menu and are never routed to.

## Install

Grab the latest zip from [Releases](https://github.com/hadifarnoud/auto-browser/releases)
and unzip into `/Applications`.

> [!IMPORTANT]
> **The app is ad-hoc signed, not notarized** (no paid Apple Developer ID),
> so Gatekeeper will block the downloaded copy with *"AutoBrowser is damaged
> or can't be opened"*. This is expected — fix it either way:
>
> ```sh
> xattr -dr com.apple.quarantine /Applications/AutoBrowser.app
> ```
>
> or right-click the app → **Open** → **Open**. Building from source needs
> neither — locally built apps are never quarantined.

Or build from source (macOS 13+, Xcode command line tools):

```sh
./build.sh install   # builds, copies to /Applications, launches
```

Then click the AutoBrowser icon in the menu bar →
**Make AutoBrowser the Default Browser…** and confirm the one-time system
dialog. Optionally enable **Launch at Login**.

## Development

```sh
swift test        # unit tests for the routing logic
swift build       # debug build of the binary
./build.sh        # assemble the .app bundle into dist/
```

Layout:

- `Sources/AutoBrowserCore` — pure, testable routing decisions and rule evaluation
- `Sources/AutoBrowser` — AppKit/SwiftUI layer: discovery, tracking, menu, rules editor, URL handling
- `docs/superpowers/specs/` — design doc

CI builds and tests every push (`.github/workflows/ci.yml`); pushing a `v*`
tag builds, zips, and publishes a GitHub release (`.github/workflows/release.yml`).

## License

[MIT](LICENSE)
