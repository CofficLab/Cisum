# CisumKernelSupport

Cisum-specific host layer on top of the shared LumiKernel: UI contribution registry, kernel event bus, app-state/theme services, plugin-compatibility extensions, and a generic observer store. It bridges the generic `KernelCore` from LumiKernel with Cisum's own plugin and provider contracts.

## Functional Logic

- **Core responsibility**: Hold everything Cisum-specific that the remote `KernelCore` (from LumiKernel) does not know about — the UI contribution registry that plugins use to donate views, the `NotificationCenter`-based event bus, the default implementations of `AppStateProviding` and `ThemeProviding`, and compatibility shims that adapt LumiKernel's `PluginCategory` / `PluginMetadata` / `SuperPlugin` types to Cisum's naming.

- **Key types / protocols** (under `Sources/CisumKernelSupport/`):
  - `PluginContributionProviding` (`Contracts/PluginContributionProviding.swift`) — the protocol plugins call during `onBoot`/`onEnable` to register root wrappers, guide/state/poster/tab/setting views, toolbar buttons, themes, and single-slot hero/right-album/control-buttons/progress contributions; `remove(owner:)` withdraws everything for a plugin.
  - `PluginProviding` (`Contracts/PluginProviding.swift`) — the query side: `allPlugins`, `getStatusViews`, `getStateViews`, `getPosterViews`, `getGuideView`, `getSettingViews`, `getSettingNavigationItems`, `getTabViews(reason:demoMode:)`, `wrapWithCurrentRoot`, `getToolBarButtons`, `getThemeContributions`, and the single-slot `getHeroView` / `getRightAlbumView` / `getControlButtonsView` / `getProgressView`. Includes `NoopPluginProvidingObserverHandle`.
  - `PluginContributionService` (`Services/PluginContributionService.swift`) — the concrete registry + aggregator. It stores contributions keyed by owner plugin id, filters to enabled plugins in startup order, caches aggregated results, dedupes theme contributions by id, and rewrites theme `sortKey` from the plugin's order.
  - `CisumKernelEvent` (`Events/CisumKernelEvent.swift`) — a `String`-backed `CaseIterable` enum of Notification names (theme, storage, enabled-plugins, playback state/progress/asset, cloud, guide, lifecycle, audio DB, scene) plus `Notification.Name` convenience statics and `NotificationCenter` subscription helpers.
  - `EventManager` (`Events/EventManager.swift`) — `@MainActor ObservableObject` that posts kernel events to `NotificationCenter`, with typed convenience methods (`postPlaybackStateDidChange`, `postPlaybackProgressDidUpdate`, `postPlaybackAssetDidChange`, etc.).
  - `BasicAppStateService` (`Services/BasicAppStateService.swift`) — default `AppStateProviding`: demo mode, DB-view visibility (persisted to `UserDefaults` key `UI.ShowDB`), importing/dragging flags, and a state-message channel.
  - `ThemeService` (`Services/ThemeService.swift`) — default `ThemeProviding`: pulls theme contributions from `PluginContributionService`, persists the selected theme id (`Cisum.SelectedThemeID`), and syncs to `LumiUIThemeRegistry`.
  - `CisumKernelError` (`Errors/CisumKernelError.swift`) — a `LocalizedError` enum covering duplicate plugin ids, missing services, plugin failures, invalid theme/storage, and `providerAlreadyRegistered`.
  - `PluginSettingNavigationItem` (`Contracts/PluginTypes.swift`) — an `Identifiable` settings navigation row (id, title, description, icon, order, destination `AnyView`).
  - Compatibility extensions (`Contracts/PluginDisplay+Compat.swift`, `Contracts/PluginMetadata+Compat.swift`) — give LumiKernel's `PluginCategory`, `PluginStage`, `PluginEnablePolicy`, `PluginMetadata`, and `SuperPlugin` Cisum-style `displayName`, `systemImage`, `iconName`, `label`, and `title` accessors.
  - `KernelEventObserverStore<Event>` / `KernelEventObserverHandle<Event>` (`Support/KernelEventObserverStore.swift`) — a generic weak-lifetime observer registry that is conformed to every provider's `ObserverHandle` protocol.
  - `KernelCore+ObservableObject.swift` — empty conformance making LumiKernel's `KernelCoreContainer` usable as a SwiftUI `@ObservedObject`.
  - `Exports.swift` — `@_exported import KernelCore` so consumers see LumiKernel's types.

- **Workflow/data flow**: Plugins call `PluginContributionProviding` methods during lifecycle callbacks (owner = kernel's `activePluginID`). At runtime the host UI calls `PluginProviding` getters, which filter by enabled plugins in startup order, sort by plugin/navigation order, cache results, and invalidate caches when plugins enable/disable. `EventManager` broadcasts cross-cutting state changes (theme, playback, cloud, scene) via `NotificationCenter`. `BasicAppStateService` and `ThemeService` are the default provider implementations the factory registers before plugins boot.

- **Dependencies** (from `Package.swift`):
  - `KernelCore` from remote `LumiKernel` (branch `main`).
  - Local: `CisumUIComponents`, `MagicKit`, `ProviderAppState`, `ProviderAudioLibrary`, `ProviderCloud`, `ProviderDevice`, `ProviderPlayback`, `ProviderStorage`, `ProviderTheme`.

## Testing Logic

This package currently has no unit tests. Verification is expected to happen at the integration layer (the app boots, plugins register, and contributions aggregate correctly); `swift build` should succeed as a compile-time check, and UI/behavioral verification is manual in the running app.

```bash
cd /Users/angel/Code/Coffic/Cisum/Packages/CisumKernelSupport
swift build
```
