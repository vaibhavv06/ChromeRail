# ChromeRail 0.3.2

ChromeRail is an invisible native macOS companion that cycles open Google Chrome windows with a two-finger horizontal gesture over Chrome's existing vertical-tabs area. If each Chrome profile has its own window, the result is profile switching equivalent to `Command-\``. There is no floating rail, Dock icon, menu-bar icon, browser injection, or embedded browser.

## Behavior

- Horizontal input is captured only when it begins inside Chrome's left-side vertical-tabs area.
- Vertical scrolling and gestures beginning elsewhere pass through unchanged.
- One physical gesture switches at most one window; momentum cannot switch again.
- Discrete horizontal mouse wheels are supported, including Logitech thumb wheels.
- ChromeRail switches only among currently open standard Chrome windows. It does not launch profiles, resize windows, change fullscreen state, or alter tabs.

## Privacy and performance

ChromeRail does not read profile data, page content, tab titles, cookies, passwords, history, or Google credentials. It uses macOS Accessibility only to identify Chrome's focused window and vertical-tabs geometry, then reacts to accessibility and workspace notifications instead of polling.

## Requirements

- Apple silicon Mac
- macOS 13 or later
- Google Chrome with vertical tabs enabled
- Accessibility permission for ChromeRail

## Build

```sh
zsh scripts/build_app.sh
```

The ad-hoc-signed app is written to `dist/ChromeRail.app`. Move it to `/Applications`, open it once, and grant it access in **System Settings → Privacy & Security → Accessibility**.

Run the gesture-safety checks with:

```sh
swift run ChromeRailChecks
```

## Distribution status

This is an arm64 alpha with no third-party runtime dependencies. Public distribution still requires a Developer ID signature, hardened runtime, notarization, and broader Chrome/macOS compatibility testing.
