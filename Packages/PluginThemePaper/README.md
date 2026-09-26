# PluginThemePaper

Paper is a warm, light "book" theme styled after paper and ink. It uses a warm off-white workspace (`#FFFCF6` medium, `#F4F0E8` deep, `#E9E1D4` light) with sepia/brown accents (`#A15C38`/`#D8A06B` primary, `#8E6F4E`/`#BFA27A` secondary, `#4C6A58`/`#7FA08B` muted-green tertiary) and warm-tinted text colors, designed for comfortable audiobook reading.

## Functional Logic

- **Core responsibility:** Ship the `PaperTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `PaperTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemePaperPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemePaperPlugin.shared`) that contributes the theme and docs.
  - `ThemePaperPluginAboutView` / `ThemePaperPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemePaperPlugin"`, `order = 200` (last in the theme picker order), metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 200, themeId: "paper")`, `chromeTheme: PaperTheme()`, `editorThemeId: "paper"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `PaperTheme`):**
  - Identifier `"paper"`, display name "Paper", icon `book.closed.fill`, appearance kind `.light`.
  - Accents — primary sepia/brown `#A15C38`/`#D8A06B`, secondary tan `#8E6F4E`/`#BFA27A`, tertiary muted green `#4C6A58`/`#7FA08B`.
  - Atmosphere — deep `#F4F0E8`/`#141210`, medium `#FFFCF6`/`#211E1A`, light `#E9E1D4`/`#312B25` (warm paper-tinted).
  - Workspace text is warm-tinted rather than neutral: `#231F1A`/`#F7F0E6`, secondary `#5E554B`/`#C7B9A7`, tertiary `#8B8175`/`#9E9184`.
  - Background: vertical linear gradient over the atmosphere colors plus a top-**leading** radial glow in the primary sepia accent (~8% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemePaperPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `PaperTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemePaper
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The warm paper palette is validated visually.
