# ProviderTheme

Defines the `ThemeProviding` protocol: aggregate plugin theme contributions, persist the selected theme, and sync the active scheme to the CisumUI theme registry. Absorbs the legacy `ThemeVM` + `ThemeService` + `LumiUIThemeRegistry` orchestration.

## Functional Logic

- **Core responsibility**: own the theme lifecycle — collect theme contributions from plugins, rewrite sort keys / dedup by plugin order, persist the selection, and push the active chrome theme + `ColorScheme` into CisumUI.
- **Key protocol**: `ThemeProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
  - Properties: `allThemeContributions: [LumiUIThemeContribution]` (sorted, deduped), `selectedThemeID: String`, `activeChromeTheme: any LumiAppChromeTheme`, `preferredColorScheme: ColorScheme?` (nil = follow system).
  - Actions: `selectTheme(_:)` (persist), `reloadThemes()` (re-aggregate from plugins), `syncToCisumUI()` (push to `LumiUIThemeRegistry`).
  - Observation: `addObserver(_:)` returns `ThemeProvidingObserverHandle`.
- **Events** (`ThemeProvidingEvent`): `.themesChanged([LumiUIThemeContribution])`, `.selectionChanged(String)`.
- **Provider pattern**: consumers call `kernel.resolveProvider((any ThemeProviding).self)`. Default `addObserver` returns `NoopThemeProvidingObserverHandle`; `cancel()` is idempotent.
- **Dependencies**: `CisumUIComponents` (`LumiUIThemeContribution`, `LumiAppChromeTheme`).

## Testing Logic

- **Test file**: `Tests/ThemeProvidingTests.swift`.
- **Key scenarios tested**:
  - A stub conforms to `ThemeProviding` (with a `ThemeStub: LumiAppChromeTheme`); default `addObserver` returns a `NoopThemeProvidingObserverHandle` without invoking callbacks.
  - `NoopThemeProvidingObserverHandle.cancel()` is repeatable.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderTheme
  swift test
  ```
- **Note**: provider package; tests verify protocol conformance and the no-op observer fallback. Real theme aggregation/registry sync lives in the theme plugin/factory.
