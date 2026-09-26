# PluginPluginManager

The plugin-management settings plugin. It registers a "Plugin Manager" settings entry that lists all user-configurable plugins, lets the user enable/disable them at runtime, shows each plugin's contributed about view (or a default fallback), and persists enable/disable overrides to disk.

## Functional Logic

- **Core responsibility:** Provide a settings UI to inspect and toggle plugins, implement the kernel's `PluginManaging` contract, and persist per-plugin enable overrides across launches.
- **Key types:**
  - `PluginPluginManager` — `@MainActor final class` conforming to `SuperPlugin`. `pluginID = "com.coffic.cisum.plugin.plugin-manager"`, `order = 90`, icon `"puzzlepiece.extension"`, category `.system`, policy `.disabled`. `settingsEntryID = "plugin-manager"`.
  - `PluginManagerProvider` — `@MainActor final class` conforming to `PluginManaging`, wrapping `KernelCoreContainer`. Exposes `allPlugins`, `configurablePlugins` (filtered by `policy.isConfigurable`), counts, enable/disable round-trips, and observer support; posts `.cisumEnabledPluginsDidChange` after changes.
  - `PluginManagerStateStore` — `@MainActor final class` conforming to `PluginStatePersisting`. Persists `[pluginID: Bool]` to `<pluginDataDirectory>/plugin-enabled-overrides.plist`, with one-time migration from the legacy `UserDefaults` key `com.coffic.cisum.pluginEnabledOverrides`.
  - `PluginManagementCapability` — internal protocol narrowing management to `configurablePlugins`, `isEnabled`, `enablePlugin`, `disablePlugin`; `PluginManagementCapabilityAdapter` adapts the manager (weakly held).
  - `PluginManagementViewModel` — `ObservableObject` publishing a `revision` counter that bumps on enable/disable changes to force list rebuilds; routes enable/disable calls.
  - `PluginManagerObserver` — subscribes to `PluginManaging` events and bumps the view model revision.
  - Views: `PluginManagementView` (two-column list + detail, with search and category filtering), `PluginListRow`, `PluginEnableControl` (toggle or policy tag), `PluginSettingsDetailView` (header + contributed about view or `PluginDefaultAboutView`), `PluginManagementHeader`, `PluginDefaultAboutView`, `PluginManagerAboutView`, `PluginManagerManualView`.
- **Plugin registration:** Registers as `PluginPluginManager`. `onBootAsync` contributes the "Plugin Manager" settings navigation item, resolves the plugin's data directory via `StorageProviding.pluginDataDirectory(for:)` and injects a `PluginManagerStateStore` as `kernel.stateStore`, then assembles the provider/adapter/view-model/observer. `onShutdownAsync` removes the contribution and tears down state.
- **Workflow/data flow:**
  1. The settings view lists configurable plugins (searchable, category-filtered) with enable toggles.
  2. Toggling calls `PluginManagerProvider.enablePlugin/disablePlugin`, which drives the kernel lifecycle, recreates contributions, writes the override plist, and posts a change notification.
  3. `PluginManagerObserver` bumps the view model revision, rebuilding the list/detail.
- **Dependencies:** `MagicKit`, `CisumKernelSupport`, `CisumUIComponents`, `ProviderDocsView`, `ProviderPluginManaging`, `ProviderStorage`. Platforms: macOS 14+, iOS 17+. Resources: `Resources`.

## Testing Logic

- **Test files:**
  - `Tests/PluginPluginManagerTests/PluginManagementCoverageTests.swift` — uses `ProbeConfigurablePlugin`/`ProbeAlwaysOnPlugin`, a `CapabilityProbe`, and a real `KernelCoreContainer` with an injected `PluginManagerStateStore`.
  - `Tests/PluginPluginManagerTests/PluginManagerStateStoreTests.swift` — exercises the plist persistence and legacy UserDefaults migration.
- **Key scenarios tested:**
  - ViewModel sources plugins from the capability, falls back to empty without one, routes enable/disable, and bumps revision.
  - Capability adapter forwards to the manager and degrades when the manager is released.
  - Observer increments revision on manager events and stops after cancellation.
  - `PluginManagerProvider` exposes the registry, filters configurable plugins, performs enable/disable round-trips, fails to enable unknown plugins, fails to disable an alwaysOn plugin (policy-protected), and supports idempotent observer cancellation.
  - Plugin lifecycle: safe `onRegister` without docs, navigation item is `nil` before boot but non-nil after boot even without storage, and shutdown tears down state.
  - `PluginManagerStateStore` persists overrides to the plist and reloads them across instances, clears entries, resets all, and migrates the legacy UserDefaults key once.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPluginManager
  swift test
  ```
- Tests are comprehensive for a manager-sized package: they cover the real kernel-backed enable/disable flow and the on-disk override persistence.
