# PluginThemeNebula

Nebula Pink is a dark theme built around soft pink and magenta accents (`#FF2D55`/`#FF375F` primary, `#AF52DE`/`#BF5AF2` purple secondary, `#FF9F0A` amber tertiary) over warm near-black surfaces (`#130E12` deep, `#1D171D` medium, `#29212A` light), keeping reading layers clean and cosmic.

## Functional Logic

- **Core responsibility:** Ship the `NebulaTheme` chrome theme (color tokens + global background) and register it with the Cisum plugin kernel so it appears in the theme picker.
- **Key types:**
  - `NebulaTheme` — a public `LumiAppChromeTheme` providing identifiers, accent/atmosphere/glow colors, workspace text colors, and `makeGlobalBackground(proxy:)`.
  - `ThemeNebulaPlugin` — a `@MainActor AsyncSuperPlugin` (singleton `ThemeNebulaPlugin.shared`) that contributes the theme and docs.
  - `ThemeNebulaPluginAboutView` / `ThemeNebulaPluginManualView` — landing/about and chapter-style user-manual views shown via the docs provider.
- **Plugin registration:** Plugin id is `"ThemeNebulaPlugin"`, `order = 180`, metadata category `.design`, stage `.stable`, policy `.alwaysOn`, version `1.0.0`. On `onRegister` it registers About/Manual docs entries; on `onBootAsync` it adds a `LumiUIThemeContribution` (sort key `(pluginOrder: 180, themeId: "nebula")`, `chromeTheme: NebulaTheme()`, `editorThemeId: "nebula"`) through `PluginContributionProviding`; `onShutdownAsync` removes it.
- **Theme characteristics (from `NebulaTheme`):**
  - Identifier `"nebula"`, display name "Nebula Pink", icon `cloud.moon.fill`, appearance kind `.dark`.
  - Accents — primary pink/red `#FF2D55`/`#FF375F`, secondary purple `#AF52DE`/`#BF5AF2`, tertiary amber `#FF9F0A`.
  - Atmosphere — deep `#FAF5F7`/`#130E12`, medium `#FFFFFF`/`#1D171D`, light `#F6EEF2`/`#29212A` (warm pink-tinted).
  - Workspace text `#1D1D1F`/`#F5F5F7` with secondary/tertiary grays.
  - Background: vertical linear gradient over the atmosphere colors plus a top-trailing pink radial glow (~10% opacity).
- **Dependencies (Package.swift):** local `MagicKit`, `CisumUIComponents`, `CisumKernelSupport`, and `ProviderDocsView`; resource `Resources/Localizable.xcstrings`. Targets macOS 14 / iOS 17.

## Testing Logic

- **Test files:** `Tests/ThemeNebulaPluginTests.swift`.
- **Key scenarios tested:** `themeIdentityIsStable()` constructs `NebulaTheme()` and asserts `identifier`, `displayName`, and `iconName` are non-empty.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginThemeNebula
  swift test
  ```
- Note: this package is a purely visual/declarative theme; unit tests only verify plugin/theme identity and registration metadata. The palette and gradient are validated visually.
