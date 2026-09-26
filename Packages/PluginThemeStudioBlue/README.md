# PluginThemeStudioBlue

Studio Blue is a professional "studio" theme built on blue-gray surfaces (`#071017` deep, `#111B24` medium, `#20303C` light in dark mode). It pairs a primary blue (`#007AFF`/`#5AC8FA`) with a green secondary (`#30D158`/`#32D74B`) and an indigo tertiary (`#5856D6`/`#7D7AFF`), and is the only theme that layers two radial glows (top-right primary, bottom-left secondary) for a focused, balanced studio look.

## Functional Logic

- **Core responsibility:** Ship the `StudioBlueTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `StudioBlueTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeStudioBluePlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeStudioBluePlugin.shared`) that contributes the theme and docs.
  - `ThemeStudioBluePluginAboutView` / `ThemeStudioBluePluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeStudioBluePlugin"`, `order = 130`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 130, themeId: "studio-blue")`, `chromeTheme: StudioBlueTheme()`, `editorThemeId: "studio-blue"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `StudioBlueTheme`):**
  - Identifier `"studio-blue"`, display name "Studio Blue", icon `waveform`, appearance kind `.system`.
  - Accents — primary blue `#007AFF`/`#5AC8FA`, secondary green `#30D158`/`#32D74B`, tertiary indigo `#5856D6`/`#7D7AFF`.
  - Atmosphere — deep `#EEF4F8`/`#071017`, medium `#FFFFFF`/`#111B24`, light `#DDEAF2`/`#20303C` (blue-gray tinted).
  - Workspace text is blue-tinted: `#17202A`/`#F3F8FC`, secondary `#4B5A67`/`#A9B8C5`, tertiary `#7B8791`/`#7F8D99`.
  - Background: vertical linear gradient over the atmosphere colors plus two radial glows — primary at top-trailing (~9%) and secondary at bottom-leading (~5%).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeStudioBluePluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `StudioBlueTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeStudioBlue
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The dual-glow blue-gray palette is validated visually.
