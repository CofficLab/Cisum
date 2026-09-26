# PluginThemeForest

Forest Green is a nature-themed palette centered on natural green accents (`#34C759`/`#30D158`, secondary `#32D74B`) with a cool cyan tertiary (`#30B0C7`). It is tuned for long audiobook/listening sessions, pairing soft green-tinted atmosphere layers with a calm, easy-on-the-eyes workspace.

## Functional Logic

- **Core responsibility:** Ship the `ForestTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `ForestTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeForestPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeForestPlugin.shared`) that contributes the theme and docs.
  - `ThemeForestPluginAboutView` / `ThemeForestPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeForestPlugin"`, `order = 150`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 150, themeId: "forest")`, `chromeTheme: ForestTheme()`, `editorThemeId: "forest"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `ForestTheme`):**
  - Identifier `"forest"`, display name "Forest Green", icon `leaf.fill`, appearance kind `.system`.
  - Accents — primary green `#34C759`/`#30D158`, secondary green `#32D74B`, tertiary cyan `#30B0C7`/`#40CBE0`.
  - Atmosphere — deep `#F5F8F5`/`#0B110D`, medium `#FFFFFF`/`#151B17`, light `#EEF4EF`/`#202820` (faintly green-tinted).
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing green radial glow (~10% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeForestPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `ForestTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeForest
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The palette and gradient are validated visually.
