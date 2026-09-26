# PluginThemeMono

Mono High Contrast is a strictly monochrome, grayscale theme. It uses near-black/near-white surfaces (`#0B0B0F` deep, `#151519` medium, `#202027` light in dark mode) and gray-only accents (`#1D1D1F`/`#F5F5F7` primary, `#6E6E73`/`#A1A1A6` secondary, `#8E8E93` tertiary) with the lowest glow intensities of any theme, deliberately emphasizing content over chrome.

## Functional Logic

- **Core responsibility:** Ship the `MonoTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `MonoTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeMonoPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeMonoPlugin.shared`) that contributes the theme and docs.
  - `ThemeMonoPluginAboutView` / `ThemeMonoPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeMonoPlugin"`, `order = 170`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 170, themeId: "mono")`, `chromeTheme: MonoTheme()`, `editorThemeId: "mono"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `MonoTheme`):**
  - Identifier `"mono"`, display name "Mono High Contrast", icon `circle.lefthalf.filled`, appearance kind `.dark`.
  - Accents — primary near-black/white `#1D1D1F`/`#F5F5F7`, secondary gray `#6E6E73`/`#A1A1A6`, tertiary gray `#8E8E93`.
  - Atmosphere — deep `#F5F5F7`/`#0B0B0F`, medium `#FFFFFF`/`#151519`, light `#EEEEF0`/`#202027`.
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Glow opacities are intentionally minimal (3% / 5% / 8%); background is a vertical linear gradient over the atmosphere colors plus a faint top-trailing primary radial glow (~6% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeMonoPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `MonoTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeMono
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The grayscale palette is validated visually.
