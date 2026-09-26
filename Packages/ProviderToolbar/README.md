# ProviderToolbar

Defines the `ToolbarProviding` protocol: an optional whole-window-toolbar injection slot. The default scene switcher has moved to `PluginScene` (plugins contribute buttons via `SuperPlugin.addToolBarButtons()`); this protocol is retained as an alternative bulk-injection contract.

## Functional Logic

- **Core responsibility**: let the host optionally inject an entire toolbar view into the root layout, rather than wiring individual toolbar buttons through plugins.
- **Key protocol**: `ToolbarProviding` (`@MainActor`, `AnyObject`, `ObservableObject`):
  - `func makeToolbarView() -> AnyView` — returns the toolbar view (e.g. a scene switcher).
  - `addObserver(_:)` returns `ToolbarProvidingObserverHandle`.
  - Uses `AnyView` instead of an `associatedtype` so the protocol can be registered as an existential (`any ToolbarProviding`) in the `KernelCoreContainer` provider registry.
- **Events** (`ToolbarProvidingEvent`): `.contentChanged`.
- **Provider pattern**: consumers resolve via `kernel.resolveProvider((any ToolbarProviding).self)`. Default `addObserver` returns `NoopToolbarProvidingObserverHandle`; `cancel()` is idempotent.
- **Dependencies**: `CisumKernelSupport`, `ProviderScene`.

## Testing Logic

- **Test file**: `Tests/ToolbarProvidingTests.swift`.
- **Key scenarios tested**:
  - A stub returns a view from `makeToolbarView()`.
  - Default `addObserver` returns a `NoopToolbarProvidingObserverHandle` without invoking callbacks.
  - `NoopToolbarProvidingObserverHandle.cancel()` is repeatable.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderToolbar
  swift test
  ```
- **Note**: provider package; tests verify protocol conformance and the no-op observer fallback.
