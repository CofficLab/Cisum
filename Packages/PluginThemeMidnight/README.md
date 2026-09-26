# PluginThemeMidnight

Midnight Blue is a dark theme built on deep blue-gray surfaces (`#090B10` deep, `#14171D` medium, `#20242C` light in dark mode) with a layered blue accent trio — `#2563EB`/`#60A5FA` primary, `#007AFF`/`#0A84FF` secondary, and `#5AC8FA`/`#64D2FF` tertiary — evoking a calm night sky for evening listening.

## Functional Logic

- **Core responsibility:** Ship the `MidnightTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `MidnightTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeMidnightPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeMidnightPlugin.shared`) that contributes the theme and docs.
  - `ThemeMidnightPluginAboutView` / `ThemeMidnightPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeMidnightPlugin"`, `order = 160`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 160, themeId: "midnight")`, `chromeTheme: MidnightTheme()`, `editorThemeId: "midnight"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `MidnightTheme`):**
  - Identifier `"midnight"`, display name "Midnight Blue", icon `moon.stars.fill`, appearance kind `.dark`.
  - Accents — primary blue `#2563EB`/`#60A5FA`, secondary system blue `#007AFF`/`#0A84FF`, tertiary light blue `#5AC8FA`/`#64D2FF`.
  - Atmosphere — deep `#F5F7FA`/`#090B10`, medium `#FFFFFF`/`#14171D`, light `#EEF3FA`/`#20242C` (faintly cool-tinted).
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing blue radial glow (~10% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeMidnightPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `MidnightTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeMidnight
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The palette and gradient are validated visually.
