# PluginSettingsButton

A small macOS toolbar plugin that adds a gear "Settings" button to the trailing edge of the main window toolbar, opening the settings window via SwiftUI `openWindow`.

## Functional Logic

- **Core responsibility:** Surface a settings entry point in the toolbar that opens the same settings window as the menu-bar "Settings…" (⌘,) command.
- **Key types:**
  - `SettingsButtonPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "SettingsButtonPlugin"`, `order = 9999`, icon `"gearshape"`, category `.system`, policy `.alwaysOn`.
  - `SettingsButtonPluginInfo` — enum with `description`, `iconName = "gearshape"`, `toolbarItemId = "settings-button"`, and `settingsWindowID = "cisum.settings"` (mirrored from `FactoryCisum.AppBootstrap.settingsWindowID` to avoid a circular dependency).
  - `SettingsButtonView` — public SwiftUI button that calls `openWindow(id: "cisum.settings")`.
  - Views: `SettingsButtonPluginAboutView`, `SettingsButtonPluginManualView`.
- **Plugin registration:** Registers as `SettingsButtonPlugin`. `onRegister` contributes About/Manual docs. `onBootAsync` contributes the toolbar button (macOS-only) via `PluginContributionProviding.addToolBarButtons`. `onShutdownAsync` removes the contribution.
- **Workflow/data flow:** The button contributes a native `Button` (the system toolbar styles it); tapping opens (and focuses) the settings window identified by `cisum.settings`.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`.

## Testing Logic

- **Test files:**
  - `Tests/SettingsButtonPluginTests.swift`.
- **Key scenarios tested:**
  - Metadata stability: `toolbarItemId = "settings-button"`, `settingsWindowID = "cisum.settings"`, `iconName = "gearshape"`, non-empty description, and `SettingsButtonView.title == "Settings"`.
  - The plugin's metadata name is "Settings", category `.system`, policy `.alwaysOn`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginSettingsButton
  swift test
  ```
- Tests are minimal — they only verify exported metadata and plugin identity. The `openWindow` behavior itself is not tested.
