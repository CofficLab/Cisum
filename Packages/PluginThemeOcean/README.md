# PluginThemeOcean

Ocean Blue is a fresh blue-cyan theme that adapts to the system light/dark appearance. It pairs cool blue surfaces (`#091015` deep, `#141B20` medium, `#202930` light in dark mode) with a blue-cyan accent progression — `#007AFF`/`#0A84FF` primary, `#30B0C7`/`#40CBE0` secondary, `#64D2FF` tertiary — for a calm, watery feel.

## Functional Logic

- **Core responsibility:** Ship the `OceanTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `OceanTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeOceanPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeOceanPlugin.shared`) that contributes the theme and docs.
  - `ThemeOceanPluginAboutView` / `ThemeOceanPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeOceanPlugin"`, `order = 190`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 190, themeId: "ocean")`, `chromeTheme: OceanTheme()`, `editorThemeId: "ocean"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `OceanTheme`):**
  - Identifier `"ocean"`, display name "Ocean Blue", icon `water.waves`, appearance kind `.system`.
  - Accents — primary blue `#007AFF`/`#0A84FF`, secondary cyan `#30B0C7`/`#40CBE0`, tertiary light blue `#64D2FF`.
  - Atmosphere — deep `#F2F8FA`/`#091015`, medium `#FFFFFF`/`#141B20`, light `#EAF3F7`/`#202930` (cool blue-tinted).
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing blue radial glow (~10% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeOceanPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `OceanTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeOcean
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The palette and gradient are validated visually.
