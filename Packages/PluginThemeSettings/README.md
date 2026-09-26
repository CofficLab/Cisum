# PluginThemeSettings

PluginThemeSettings is not a color theme — it is the theme **management and settings UI** for Cisum. It contributes an "Appearance" navigation entry to the Settings window that lists every theme contributed by the color-theme plugins, lets the user search and filter by appearance (All / Dark / Light / System), preview each theme's accent and atmosphere colors, and apply a selection. It mirrors the Lumi `ThemePackPlugin` settings-entry pattern.

## Functional Logic

- **Core responsibility:** Register the Settings → Appearance entry, host a long-lived `ThemeSettingsViewModel` fed by the kernel's `ThemeProviding` provider, and render a two-column theme picker (list + live preview) that calls back into the kernel to switch themes.
- **Key types:**
  - `ThemeSettingsPlugin` — a `@MainActor AsyncSuperPlugin` (singleton) that registers docs, contributes the `appearance` settings navigation item, and installs/tears down the settings state.
  - `ThemeSettingsPluginInfo` — namespace holding `title = "Theme"`, `description = "Switch app theme"`, `iconName = "paintbrush"`, `order = 140`.
  - `ThemeSettingsCapability` (protocol) / `ThemeSettingsCapabilityAdapter` — a minimal theme capability (`allThemeContributions`, `selectedThemeID`, `selectTheme(_:)`) that adapts the kernel's `ThemeProviding` so the ViewModel does not depend on it directly.
  - `ThemeSettingsViewModel` — an `ObservableObject` exposing `themes` and `currentThemeID`, with `selectTheme(_:)` and `handleProviderChanged()`.
  - `ThemeProvidingObserver` — subscribes to `ThemeProviding` change events, performs an initial sync, and forwards updates to the ViewModel; `cancel()` stops updates.
  - `ThemeAppearanceFilter` — enum `all / dark / light / system` with `matches(_: ThemeAppearanceKind)`.
  - Views: `ThemeSettingsDetailView` (two-column list + `ThemePreviewPane`), `ThemeSettingsRootView` (compact row-based picker used in the aggregated settings page), `ThemeSwatches` (four-dot accent/atmosphere swatch), plus `ThemeSettingsPluginAboutView` / `ThemeSettingsPluginManualView` docs views.
- **Plugin registration:** Plugin id is `"ThemeSettingsPlugin"`, metadata category `.system`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it adds About/Manual docs entries. On `onBootAsync` (and `onEnable`) it resolves `ThemeProviding` and builds a single long-lived `ThemeSettingsViewModel` + `ThemeProvidingObserver`; it contributes a `PluginSettingNavigationItem(id: "appearance", title: "Appearance", iconName: "paintpalette", order: 2, destination: ThemeSettingsDetailView)`. `onDisable`/`onShutdownAsync` cancel the observer and release the state.
- **UI characteristics:** The detail view shows a header with theme count and current theme, a search bar plus segmented appearance filter, a scrollable theme list (icon, name, description, active dot), and a right-hand preview pane that renders the selected theme's icon, description, appearance label, component/button previews, and color swatches drawn from `chromeTheme.accentColors()` and `atmosphereColors()`. `ThemeSwatches` renders four dots: atmosphere deep/light plus accent primary/secondary.
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, `ProviderDocsView`, and `ProviderTheme`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeSettingsPluginTests.swift` (this package has substantially richer tests than the color-theme plugins).
- **Key scenarios tested:**
  - `pluginInfoExportsRegistrationMetadata()` — asserts `ThemeSettingsPluginInfo.iconName == "paintbrush"` and `order == 140`.
  - `themeObserverPerformsInitialSync()` / `themeObserverForwardsSelectionToViewModel()` — using an in-memory `ThemeService` with a `TestChromeTheme`, verifies the observer syncs existing state on install and propagates `reloadThemes()` changes into the ViewModel.
  - `themeObserverCancelStopsViewModelUpdates()` — after `cancel()`, a kernel reload no longer overwrites the ViewModel selection.
  - `ThemeSettingsViewModelTests` (via a `ThemeSettingsCapabilityProbe`) — init reflects capability state, `selectTheme(_:)` forwards to the capability, `handleProviderChanged()` refreshes the current id, and a `nil` capability keeps an empty state.
  - `appearanceFilterMatchesKinds()` — verifies the `all/dark/light/system` filters match (and reject) the correct `ThemeAppearanceKind` values.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeSettings
  swift test
  ```
- Note: unlike the color-theme plugins (which only assert identity), this package tests the real ViewModel/observer/capability wiring against an in-memory `ThemeService`; SwiftUI view layout itself is not unit-tested.
