# ProviderSettingsHost

Shared iOS host shell for the settings experience: renders plugin-contributed navigation-bar items and presents the settings sheet. Ported verbatim from GameFactory's `Packages/ProviderSettingsHost` so both apps share one implementation.

## Functional Logic

- **Core responsibility**: let an iOS app surface a settings entry point (gear button) on its own navigation bar, and present the settings UI as a sheet when tapped.
- **Key types**:
  - `IOSSettingsAppShell` — `@MainActor public struct`. Wraps the host's main view and listens for `SettingViewNavigation.openSettingsNotification` to present `settingsView` in a sheet (fixed `.large` detent with a visible drag indicator).
    - `NavigationBarMode.host` — the host owns a `NavigationStack` and mounts the contributed items itself at stack level; the shell does not draw any bar (avoids a "self-drawn bar + system bar" double header).
    - `NavigationBarMode.overlay` — the host has no system navigation stack; the shell draws a 48pt bar to carry the contributed items.
  - `IOSNavigationBarItemsBridge` — `@MainActor public final class: ObservableObject`. Bridges `IOSNavigationBarProviding.visibleNavigationBarItems` into `[AnyView]`, sorted by `order` then `id`, and forwards provider change signals (values are read at render time, so a stale read cannot happen).
  - `IOSNavigationBarHost` — renders leading/principal/trailing items in a self-drawn bar. Used only by the `.overlay` mode.
- **Why the stack-level mount matters**: SwiftUI's `.toolbar` only applies to the **nearest** navigation container. A `.toolbar` attached outside a nested `NavigationStack` is consumed by the outer context (and never appears), and is not propagated into the nested stack. Hosts that own a `NavigationStack` must therefore mount plugin-contributed items at stack level themselves.
- **Dependencies**: `ProviderToolbar (LumiProviders)`, `ProviderSettingView (LumiSettings)`. Platforms: iOS 17+, macOS 14+ (all sources are `#if os(iOS)`).

## Testing Logic

- **Test file**: `Tests/ProviderSettingsHostTests/ProviderSettingsHostTests.swift`.
- **Key scenarios tested**:
  - The bridge forwards every visible navigation-bar item.
  - The bridge returns an empty array when the provider has no contributions.
  - The bridge respects `visibleCategories` filtering.
  - The bridge reflects contributions added after the bridge was created.
- **Running tests** (the package is iOS-only, so use a simulator destination):
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderSettingsHost
  xcodebuild test -scheme ProviderSettingsHost \
    -destination 'platform=iOS Simulator,name=<device>'
  ```
- **Note**: `swift test` reports 0 tests on macOS because every source file is gated behind `#if os(iOS)`.
