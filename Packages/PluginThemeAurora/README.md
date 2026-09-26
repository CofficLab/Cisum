# PluginThemeAurora

Aurora is a dark-leaning color theme for Cisum built around low-saturation purple accents. It pairs a near-black violet workspace (`#100E14` deep, `#19171F` medium, `#24212D` light in dark mode) with a soft indigo/cyan accent trio, evoking a purple aurora over the night sky while keeping a light, spacious feel in light mode.

## Functional Logic

- **Core responsibility:** Ship the `AuroraTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `AuroraTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeAuroraPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeAuroraPlugin.shared`) that contributes the theme and docs.
  - `ThemeAuroraPluginAboutView` / `ThemeAuroraPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeAuroraPlugin"` (`String(describing:)`), `order = 120`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 120, themeId: "aurora")`, `chromeTheme: AuroraTheme()`, `editorThemeId: "aurora"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `AuroraTheme`):**
  - Identifier `"aurora"`, display name "Aurora Purple", icon `sparkles`, appearance kind `.dark`.
  - Accents — primary purple `#AF52DE`/`#BF5AF2`, secondary indigo `#5E5CE6`, tertiary cyan `#64D2FF`.
  - Atmosphere — deep `#F7F5FA`/`#100E14`, medium `#FFFFFF`/`#19171F`, light `#F1EEF6`/`#24212D`.
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing radial glow in the primary accent.
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeAuroraPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `AuroraTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeAurora
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The actual color palette and gradient rendering are validated visually.
