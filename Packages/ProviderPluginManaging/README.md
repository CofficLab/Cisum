# ProviderPluginManaging

Defines the `PluginManaging` protocol: read access to all registered plugins and runtime enable/disable control, used by the Settings plugin-management page.

## Functional Logic

- **Core responsibility**: let the Settings UI list every plugin (including disabled ones), filter to user-configurable ones, and toggle them at runtime — writing the user override, rebuilding contributions, and persisting.
- **Key protocol**: `PluginManaging` (`@MainActor`, `AnyObject`):
  - Read properties: `allPlugins: [any SuperPlugin]`, `configurablePlugins: [any SuperPlugin]` (policy allows user toggling: optOut/optIn), `pluginCount: Int`, `enabledCount: Int`, `lastErrorDescription: String?`.
  - Queries: `plugin(id:) -> (any SuperPlugin)?`, `isRegistered(id:) -> Bool`, `enabledPlugins(from:) -> [any SuperPlugin]`, `isEnabled(id:) -> Bool` (combines policy + user override).
  - Mutations: `enablePlugin(id:) async -> Bool`, `disablePlugin(id:) async -> Bool` (return success; on failure `lastErrorDescription` is populated).
  - Observation: `addObserver(_:)` returns `PluginManagingObserverHandle`.
- **Events** (`PluginManagingEvent`): `.enabledPluginsChanged` — fired on the main thread after state has already updated.
- **Provider pattern**: consumers resolve via `kernel.resolveProvider((any PluginManaging).self)`. The default `addObserver` returns `NoopPluginManagingObserverHandle`; `cancel()` is idempotent.
- **Dependencies**: `CisumKernelSupport` (`SuperPlugin`, `PluginProviding` types), `CisumUIComponents`.

## Testing Logic

- **Test file**: `Tests/PluginManagingTests.swift`.
- **Key scenarios tested**:
  - A stub conforms to `PluginManaging`; default `addObserver` returns a `NoopPluginManagingObserverHandle` without invoking callbacks.
  - `NoopPluginManagingObserverHandle.cancel()` is repeatable.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderPluginManaging
  swift test
  ```
- **Note**: provider package; tests verify protocol conformance and the no-op observer fallback. Real enable/disable orchestration lives in the kernel/factory.
