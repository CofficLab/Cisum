# PluginThemeGraphiteBlack

Graphite Black is a neutral dark theme built from layered black-gray surfaces (`#050506` deep, `#121214` medium, `#232326` light in dark mode). It keeps accents deliberately restrained — a neutral gray primary (`#3A3A3C`/`#D1D1D6`), a single blue accent (`#0A84FF`/`#64D2FF`) used for the glow, and a gray tertiary — suited to extended night listening.

## Functional Logic

- **Core responsibility:** Ship the `GraphiteBlackTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `GraphiteBlackTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeGraphiteBlackPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeGraphiteBlackPlugin.shared`) that contributes the theme and docs.
  - `ThemeGraphiteBlackPluginAboutView` / `ThemeGraphiteBlackPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeGraphiteBlackPlugin"`, `order = 155`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 155, themeId: "graphite-black")`, `chromeTheme: GraphiteBlackTheme()`, `editorThemeId: "graphite-black"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `GraphiteBlackTheme`):**
  - Identifier `"graphite-black"`, display name "Graphite Black", icon `circle.lefthalf.filled`, appearance kind `.dark`.
  - Accents — primary gray `#3A3A3C`/`#D1D1D6`, secondary blue `#0A84FF`/`#64D2FF`, tertiary gray `#6E6E73`/`#8E8E93`.
  - Atmosphere — deep `#F5F5F7`/`#050506`, medium `#FFFFFF`/`#121214`, light `#E9EAED`/`#232326`.
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing radial glow driven by the secondary blue accent (~8% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeGraphiteBlackPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `GraphiteBlackTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeGraphiteBlack
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The palette and gradient are validated visually.
