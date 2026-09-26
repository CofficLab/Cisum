# ProviderSettings

Provides the app-level Settings window (`SettingsWindow`), its view model (`SettingsWindowViewModel`), and the sidebar header (`SettingsHeaderView`). Rather than defining a new protocol, it consumes the `PluginProviding` contract to render each plugin's contributed settings navigation entries in a two-column layout.

## Functional Logic

- **Core responsibility**: host the Settings window — a left sidebar of plugin-contributed navigation entries and a right detail pane — and refresh when plugins or their contributions change.
- **Key types**:
  - `SettingsWindow`: SwiftUI `View`. On macOS uses a custom `AppSettingsSidebarShell` + `AppSettingsSidebarContainer` + `AppSettingsDetailPane` (not `NavigationSplitView`, to avoid the system detail inset); on iOS uses a `NavigationSplitView`. Shows `ContentUnavailableView` when no entries exist.
  - `SettingsWindowViewModel` (`@MainActor`, `ObservableObject`): holds `@Published navigationItems: [PluginSettingNavigationItem]`, observes `PluginProvidingEvent` (`.pluginsChanged`, `.contributionsChanged`) and refreshes; `attach(to:)` detaches the old provider and subscribes to the new one.
  - `SettingsHeaderView`: sidebar top header showing the app icon (`.app` icon on macOS, `app.fill` fallback), name, version, and build via `AppSettingsSidebarHeader` / `AppBundleInfo`.
- **Dependencies**: `CisumKernelSupport` (`PluginProviding`, `PluginSettingNavigationItem`, `PluginProvidingEvent`), `CisumUIComponents` (settings shell components, `@LumiTheme`), plus provider contracts `ProviderAppState`, `ProviderStorage`, `ProviderScene`, `ProviderTheme`.

## Testing Logic

- **Test file**: `Tests/SettingsWindowTests.swift`.
- **Key scenarios tested**:
  - The view model refreshes on both `.pluginsChanged` and `.contributionsChanged`; `attach(to: aReplacement)` detaches the old provider's observer and subscribes to the new one; attaching `nil` clears state.
  - The view model handles a missing or initially-empty provider gracefully.
  - `SettingsWindow` (nil provider, populated provider) and `SettingsHeaderView` bodies can be constructed.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderSettings
  swift test
  ```
- **Note**: this package ships views and a view model rather than a pure protocol; tests focus on the view-model refresh/detach lifecycle and body construction.
