# PluginThemeCisum

Cisum is the app's signature original sunset-gradient theme. It leads with a warm orange-to-amber gradient (orange-red `#FF512F`, amber `#F09819`, with a blue `#4A90E2` tertiary accent) and renders its global background as a semi-transparent sunset linear gradient layered over `.ultraThinMaterial`, adapting to the system light/dark appearance.

## Functional Logic

- **Core responsibility:** Ship the `CisumTheme` chrome theme (the branded default look) and register it with the Cisum plugin kernel so it is selectable in the theme picker.
- **Key types:**
  - `CisumTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeCisumPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeCisumPlugin.shared`) that contributes the theme and docs.
  - `ThemeCisumPluginAboutView` / `ThemeCisumPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeCisumPlugin"`, `order = 100` (the first theme in picker order), metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 100, themeId: "cisum")`, `chromeTheme: CisumTheme()`, `editorThemeId: "cisum"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `CisumTheme`):**
  - Identifier `"cisum"`, display name "Cisum", icon `sunset.fill`, appearance kind `.system`.
  - Accents — primary orange-red `#FF512F`/`#FF8A4C`, secondary amber `#F09819`/`#FBBF24`, tertiary blue `#4A90E2`/`#60A5FA`.
  - Atmosphere colors are opacity-tinted versions of the accent hues (deep/medium ~18%, light ~34%) rather than neutral grays.
  - Workspace text `#1C1C1E`/`#FFFFFF`, warm secondary `#3A2A22`/`#F5E6DC`, tertiary `#6F5147`/`#D7B7A5`.
  - Background: a top-to-bottom orange→amber linear gradient (at 70% opacity) over `.ultraThinMaterial`.
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeCisumPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `CisumTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeCisum
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The gradient and material background are validated visually.
