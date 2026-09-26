# PluginThemeSunset

Sunset Orange is a warm theme that keeps a clean, near-white background while dressing accents in a sunset palette — orange `#FF9500`/`#FF9F0A` primary, red `#FF3B30`/`#FF453A` secondary, and yellow `#FFD60A` tertiary — over warm-tinted surfaces (`#120F0B` deep, `#1D1914` medium, `#29231B` light in dark mode).

## Functional Logic

- **Core responsibility:** Ship the `SunsetTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `SunsetTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeSunsetPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeSunsetPlugin.shared`) that contributes the theme and docs.
  - `ThemeSunsetPluginAboutView` / `ThemeSunsetPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeSunsetPlugin"`, `order = 140`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 140, themeId: "sunset")`, `chromeTheme: SunsetTheme()`, `editorThemeId: "sunset"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `SunsetTheme`):**
  - Identifier `"sunset"`, display name "Sunset Orange", icon `sunset.fill`, appearance kind `.system`.
  - Accents — primary orange `#FF9500`/`#FF9F0A`, secondary red `#FF3B30`/`#FF453A`, tertiary yellow `#FFD60A`.
  - Atmosphere — deep `#FAF7F2`/`#120F0B`, medium `#FFFFFF`/`#1D1914`, light `#F5EFE6`/`#29231B` (warm cream-tinted).
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing orange radial glow (~10% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeSunsetPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `SunsetTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeSunset
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The warm sunset palette is validated visually.
