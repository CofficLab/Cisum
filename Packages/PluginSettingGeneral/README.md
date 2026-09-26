# PluginSettingGeneral

The "General" settings plugin. It contributes the first settings entry (order 1) showing app information and a browser for the user manuals contributed by all plugins.

## Functional Logic

- **Core responsibility:** Display app metadata (name, bundle ID, version, build) and provide a master-detail manual browser that lists every plugin's contributed manual entry.
- **Key types:**
  - `SettingGeneralPlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "SettingGeneralPlugin"`, `order = 1`, icon `"gearshape"`, category `.core`, policy `.alwaysOn`.
  - `GeneralSettingsViewModel` — `ObservableObject` holding the injected `manualEntries: [DocsEntry]`.
  - `GeneralSettingsDetailView` — the General settings page: app info section, manual browser entry, and a DEBUG-only "Open Data Directory" row.
  - `ManualsBrowserView` — master-detail sheet: sidebar of plugin names, detail pane rendering the selected manual's view.
  - Views: `SettingGeneralPluginAboutView`, `SettingGeneralPluginManualView`.
- **Plugin registration:** Registers as `SettingGeneralPlugin`. `onRegister` contributes About/Manual docs. `onBootAsync` contributes the "general" settings navigation item (title "General", order 1), building the view model from `DocsViewProviding.manualEntries`.
- **Workflow/data flow:**
  1. On boot, the plugin reads all manual entries from the `DocsViewProviding` provider.
  2. The settings page shows app info and a "Browse the manuals" row that opens `ManualsBrowserView`.
  3. Selecting a manual in the sidebar renders that plugin's manual view in the detail pane.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/GeneralSettingsTests.swift`.
- **Key scenarios tested:**
  - ViewModel defaults to no manuals and preserves injected entries in order.
  - Plugin registers its own About/Manual docs, `addSettingView()` returns `nil`, and the navigation item has id `"general"`, title `"General"`, order matching `plugin.order`.
  - Registration is safe when no `DocsViewProviding` exists.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginSettingGeneral
  swift test
  ```
- Tests cover docs registration and the navigation item; the manual browser's UI is not exercised.
